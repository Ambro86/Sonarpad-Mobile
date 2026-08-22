#include "sonarpad_audio_dsp.h"

#include <algorithm>
#include <atomic>
#include <array>
#include <cmath>
#include <cerrno>
#include <complex>
#include <cstdio>
#include <cstring>
#include <limits>
#include <memory>
#include <random>
#include <string>
#include <vector>

namespace {

constexpr float kPi = 3.14159265358979323846f;
constexpr float kTwoPi = 2.0f * kPi;
constexpr int kBlockFrames = 4096;
thread_local std::string g_last_error;
std::atomic<bool> g_cancel_requested{false};

inline float clampf(float v, float lo = -1.0f, float hi = 1.0f) {
  return std::max(lo, std::min(hi, v));
}

inline float lerpf(float a, float b, float t) { return a + (b - a) * t; }

class FastRng {
 public:
  explicit FastRng(uint32_t seed = 0x534f4e41u) : state_(seed ? seed : 1u) {}
  uint32_t nextU32() {
    uint32_t x = state_;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    state_ = x;
    return x;
  }
  float uniform() {
    return static_cast<float>(nextU32() & 0x00ffffffu) / 8388607.5f - 1.0f;
  }
  float positive() {
    return static_cast<float>(nextU32() & 0x00ffffffu) / 16777215.0f;
  }

 private:
  uint32_t state_;
};

class Biquad {
 public:
  enum class Type { lowpass, highpass, bandpass, peaking };

  void configure(Type type, float sample_rate, float frequency, float q = 0.707f,
                 float gain_db = 0.0f) {
    frequency = std::clamp(frequency, 10.0f, sample_rate * 0.47f);
    q = std::max(0.05f, q);
    const float w0 = kTwoPi * frequency / sample_rate;
    const float c = std::cos(w0);
    const float s = std::sin(w0);
    const float alpha = s / (2.0f * q);
    float b0, b1, b2, a0, a1, a2;
    if (type == Type::lowpass) {
      b0 = (1.0f - c) * 0.5f;
      b1 = 1.0f - c;
      b2 = b0;
      a0 = 1.0f + alpha;
      a1 = -2.0f * c;
      a2 = 1.0f - alpha;
    } else if (type == Type::highpass) {
      b0 = (1.0f + c) * 0.5f;
      b1 = -(1.0f + c);
      b2 = b0;
      a0 = 1.0f + alpha;
      a1 = -2.0f * c;
      a2 = 1.0f - alpha;
    } else if (type == Type::bandpass) {
      b0 = alpha;
      b1 = 0.0f;
      b2 = -alpha;
      a0 = 1.0f + alpha;
      a1 = -2.0f * c;
      a2 = 1.0f - alpha;
    } else {
      const float a = std::pow(10.0f, gain_db / 40.0f);
      b0 = 1.0f + alpha * a;
      b1 = -2.0f * c;
      b2 = 1.0f - alpha * a;
      a0 = 1.0f + alpha / a;
      a1 = -2.0f * c;
      a2 = 1.0f - alpha / a;
    }
    b0_ = b0 / a0;
    b1_ = b1 / a0;
    b2_ = b2 / a0;
    a1_ = a1 / a0;
    a2_ = a2 / a0;
  }

  float process(float x) {
    const float y = b0_ * x + z1_;
    z1_ = b1_ * x - a1_ * y + z2_;
    z2_ = b2_ * x - a2_ * y;
    return std::isfinite(y) ? y : 0.0f;
  }

  void reset() { z1_ = z2_ = 0.0f; }

 private:
  float b0_ = 1.0f, b1_ = 0.0f, b2_ = 0.0f, a1_ = 0.0f, a2_ = 0.0f;
  float z1_ = 0.0f, z2_ = 0.0f;
};

class DelayLine {
 public:
  explicit DelayLine(int size = 2) : data_(std::max(2, size), 0.0f) {}
  void resize(int size) {
    data_.assign(std::max(2, size), 0.0f);
    write_ = 0;
  }
  void push(float x) {
    data_[write_] = x;
    write_ = (write_ + 1) % data_.size();
  }
  float read(float delay_samples) const {
    delay_samples = std::clamp(delay_samples, 0.0f,
                               static_cast<float>(data_.size() - 2));
    float pos = static_cast<float>(write_) - 1.0f - delay_samples;
    while (pos < 0.0f) pos += static_cast<float>(data_.size());
    const int i0 = static_cast<int>(pos) % static_cast<int>(data_.size());
    const int i1 = (i0 + 1) % static_cast<int>(data_.size());
    const float f = pos - std::floor(pos);
    return lerpf(data_[i0], data_[i1], f);
  }

 private:
  std::vector<float> data_;
  size_t write_ = 0;
};

class PitchShifter {
 public:
  PitchShifter(float sample_rate, float ratio)
      : sample_rate_(sample_rate), ratio_(ratio),
        delay_(static_cast<int>(sample_rate * 0.12f) + 8) {
    window_ = sample_rate * 0.055f;
  }

  float process(float x) {
    delay_.push(x);
    // Two cross-faded variable-delay heads. This is deliberately bounded and
    // streaming-safe: output length always matches input length.
    phase_ += (1.0f - ratio_) / window_;
    phase_ -= std::floor(phase_);
    const float p1 = phase_;
    const float p2 = std::fmod(phase_ + 0.5f, 1.0f);
    const float d1 = 8.0f + p1 * window_;
    const float d2 = 8.0f + p2 * window_;
    const float w1 = 0.5f - 0.5f * std::cos(kTwoPi * p1);
    const float w2 = 0.5f - 0.5f * std::cos(kTwoPi * p2);
    const float norm = std::max(0.1f, w1 + w2);
    return (delay_.read(d1) * w1 + delay_.read(d2) * w2) / norm;
  }

 private:
  float sample_rate_;
  float ratio_;
  float window_;
  float phase_ = 0.0f;
  DelayLine delay_;
};

class SimpleReverb {
 public:
  explicit SimpleReverb(int sample_rate)
      : d1_(sample_rate * 31 / 1000 + 4),
        d2_(sample_rate * 43 / 1000 + 4),
        d3_(sample_rate * 59 / 1000 + 4),
        d4_(sample_rate * 73 / 1000 + 4) {}

  float process(float x, float feedback = 0.55f) {
    const float a = d1_.read(0.0f);
    const float b = d2_.read(0.0f);
    const float c = d3_.read(0.0f);
    const float d = d4_.read(0.0f);
    d1_.push(x + (b - c) * feedback);
    d2_.push(x + (c - d) * feedback * 0.93f);
    d3_.push(x + (d - a) * feedback * 0.89f);
    d4_.push(x + (a - b) * feedback * 0.85f);
    return (a + b + c + d) * 0.25f;
  }

 private:
  DelayLine d1_, d2_, d3_, d4_;
};

class FilterBankVocoder {
 public:
  FilterBankVocoder(int sample_rate, int bands = 18)
      : sample_rate_(sample_rate), bands_(std::clamp(bands, 8, 28)) {
    mod_.resize(bands_);
    carrier_.resize(bands_);
    envelopes_.assign(bands_, 0.0f);
    const float lo = 100.0f;
    const float hi = std::min(9000.0f, sample_rate * 0.42f);
    for (int i = 0; i < bands_; ++i) {
      const float t = static_cast<float>(i) / std::max(1, bands_ - 1);
      const float f = lo * std::pow(hi / lo, t);
      mod_[i].configure(Biquad::Type::bandpass, sample_rate, f, 2.2f);
      carrier_[i].configure(Biquad::Type::bandpass, sample_rate, f, 2.2f);
    }
  }

  float process(float modulator, float excitation, float attack_ms,
                float release_ms) {
    const float attack = std::exp(-1.0f /
        (sample_rate_ * std::max(0.001f, attack_ms * 0.001f)));
    const float release = std::exp(-1.0f /
        (sample_rate_ * std::max(0.002f, release_ms * 0.001f)));
    float out = 0.0f;
    for (int i = 0; i < bands_; ++i) {
      const float m = std::fabs(mod_[i].process(modulator));
      const float coeff = m > envelopes_[i] ? attack : release;
      envelopes_[i] = coeff * envelopes_[i] + (1.0f - coeff) * m;
      out += carrier_[i].process(excitation) * envelopes_[i];
    }
    return out * (2.2f / std::sqrt(static_cast<float>(bands_)));
  }

 private:
  int sample_rate_;
  int bands_;
  std::vector<Biquad> mod_, carrier_;
  std::vector<float> envelopes_;
};

struct Stereo { float l = 0.0f; float r = 0.0f; };

class AssetLoop {
 public:
  bool load(const char* path, int channels) {
    data_.clear();
    frames_ = 0;
    channels_ = channels;
    if (!path || path[0] == '\0' || channels < 1) return false;
    FILE* file = std::fopen(path, "rb");
    if (!file) return false;
    if (std::fseek(file, 0, SEEK_END) != 0) {
      std::fclose(file);
      return false;
    }
    const long bytes = std::ftell(file);
    const long frame_bytes = static_cast<long>(channels * sizeof(float));
    if (bytes <= 0 || frame_bytes <= 0 || bytes % frame_bytes != 0 ||
        std::fseek(file, 0, SEEK_SET) != 0) {
      std::fclose(file);
      return false;
    }
    const size_t samples = static_cast<size_t>(bytes / sizeof(float));
    data_.resize(samples);
    const size_t read = std::fread(data_.data(), sizeof(float), samples, file);
    std::fclose(file);
    if (read != samples) {
      data_.clear();
      return false;
    }
    frames_ = samples / static_cast<size_t>(channels);
    crossfade_frames_ = std::min<size_t>(frames_ / 4, 22050u);
    if (frames_ < 32) {
      data_.clear();
      frames_ = 0;
      return false;
    }
    return true;
  }

  bool available() const { return frames_ > 0; }

  Stereo sample(uint64_t frame_index) const {
    if (!available()) return {};
    const size_t index = static_cast<size_t>(frame_index % frames_);
    Stereo current = frame(index);
    if (crossfade_frames_ == 0 || index < frames_ - crossfade_frames_) {
      return current;
    }
    const size_t fade_index = index - (frames_ - crossfade_frames_);
    const float mix = static_cast<float>(fade_index) /
                      static_cast<float>(std::max<size_t>(1, crossfade_frames_));
    const Stereo start = frame(fade_index % frames_);
    return {lerpf(current.l, start.l, mix), lerpf(current.r, start.r, mix)};
  }

 private:
  Stereo frame(size_t index) const {
    const size_t base = index * static_cast<size_t>(channels_);
    const float l = data_[base];
    const float r = channels_ > 1 ? data_[base + 1] : l;
    return {std::isfinite(l) ? l : 0.0f, std::isfinite(r) ? r : 0.0f};
  }

  std::vector<float> data_;
  size_t frames_ = 0;
  size_t crossfade_frames_ = 0;
  int channels_ = 0;
};

class DspProcessor {
 public:
  DspProcessor(int id, float amount, int sample_rate)
      : id_(id), amount_(std::clamp(amount, 0.0f, 1.0f)), sr_(sample_rate),
        delay_l_(sample_rate * 2 + 16), delay_r_(sample_rate * 2 + 16),
        short_delay_(sample_rate / 4 + 16), reverb_(sample_rate),
        pitch_low_(sample_rate, 0.82f), pitch_very_low_(sample_rate, 0.67f),
        pitch_high_(sample_rate, 1.20f), pitch_very_high_(sample_rate, 1.42f),
        pitch_vader_(sample_rate, 0.72f), pitch_mosquito_(sample_rate, 1.62f),
        pitch_songbird_(sample_rate, 1.34f), pitch_turtle_(sample_rate, 0.74f),
        many_low_(sample_rate, 0.91f), many_high_(sample_rate, 1.09f),
        many_far_(sample_rate, 1.18f),
        vocoder_(sample_rate, id == 2 ? 28 : 22), rng_(0x534f4e41u + id * 7919u) {
    hp_.configure(Biquad::Type::highpass, sr_, 90.0f);
    lp_.configure(Biquad::Type::lowpass, sr_, 9000.0f);
    bp_.configure(Biquad::Type::bandpass, sr_, 1600.0f, 0.8f);
    tone_low_.configure(Biquad::Type::lowpass, sr_, 420.0f);
    tone_high_.configure(Biquad::Type::highpass, sr_, 2700.0f);
    choir_consonants_.configure(Biquad::Type::highpass, sr_, 3200.0f, 0.72f);
    robot_consonants_.configure(Biquad::Type::highpass, sr_, 3400.0f, 0.72f);
    robot_output_highpass_.configure(Biquad::Type::highpass, sr_, 185.0f,
                                     0.72f);
    robot_clarity_highpass_.configure(Biquad::Type::highpass, sr_, 240.0f,
                                      0.72f);
    robot_clarity_lowpass_.configure(Biquad::Type::lowpass, sr_, 4300.0f,
                                     0.72f);
  }

  Stereo process(float l, float r, Stereo asset, bool has_asset) {
    const float mono = 0.5f * (l + r);
    const float dry_l = l;
    const float dry_r = r;
    Stereo wet{mono, mono};
    switch (id_) {
      case 1: wet = chorusWithAsset(l, r, asset, has_asset); break;
      case 2: wet = robot(mono, false); break;
      case 3: wet = robot(mono, true); break;
      case 4: wet = oldRadio(mono, asset, has_asset); break;
      case 5: wet = alien(mono); break;
      case 6: wet = pitchVoice(mono, pitch_low_, 0.95f); break;
      case 7: wet = pitchVoice(mono, pitch_very_low_, 0.92f); break;
      case 8: wet = pitchVoice(mono, pitch_high_, 0.95f); break;
      case 9: wet = pitchVoice(mono, pitch_very_high_, 0.90f); break;
      case 10: wet = monster(mono); break;
      case 11: wet = pitchVoice(mono, pitch_very_high_, 1.06f); break;
      case 12: wet = brightVoice(mono); break;
      case 13: wet = darkVoice(mono); break;
      case 15: wet = talkingGuitar(mono, asset, has_asset); break;
      case 16: wet = mosquito(mono); break;
      case 17: wet = oneOfMany(mono); break;
      case 18: wet = organVocoder(mono, asset, has_asset); break;
      case 19: wet = warped(l, r); break;
      case 21: wet = swirling(l, r); break;
      case 22: wet = vader(mono); break;
      case 23: wet = metallic(mono); break;
      case 24: wet = songbird(mono); break;
      case 25: wet = exterminator(mono); break;
      case 26: wet = has_asset ? ambienceAsset(mono, asset, 26) : rainThunder(mono); break;
      case 27: wet = has_asset ? ambienceAsset(mono, asset, 27) : jungle(mono); break;
      case 28: wet = has_asset ? ambienceAsset(mono, asset, 28) : crowd(mono); break;
      case 29: wet = has_asset ? ambienceAsset(mono, asset, 29) : slotMachines(mono); break;
      case 30: wet = has_asset ? ambienceAsset(mono, asset, 30) : traffic(mono); break;
      case 31: wet = spaceship(mono); break;
      case 32: wet = has_asset ? ambienceAsset(mono, asset, 32) : cricket(mono); break;
      case 33: wet = siren(mono); break;
      case 34: wet = has_asset ? ambienceAsset(mono, asset, 34) : sleighBells(mono); break;
      case 35: wet = dj(mono); break;
      case 36: wet = has_asset ? ambienceAsset(mono, asset, 36) : applause(mono); break;
      case 37: wet = badMelody(mono); break;
      case 38: wet = badHarmony(mono); break;
      case 39: wet = warmVoice(mono); break;
      case 40: wet = turtle(mono); break;
      case 41: wet = haunting(mono); break;
      default: wet = {l, r}; break;
    }
    // With the melodic choir carrier, a conventional dry/wet blend would
    // leave the original speaking pitch in the foreground. Keep the choir
    // almost entirely wet so the articulated voice follows the sung chords.
    const float mix = id_ == 1 && has_asset
                      ? 0.82f + 0.18f * amount_
                      : id_ == 2
                          ? 0.96f + 0.04f * amount_
                          : 0.18f + 0.82f * amount_;
    Stereo out;
    out.l = clampf(lerpf(dry_l, wet.l, mix));
    out.r = clampf(lerpf(dry_r, wet.r, mix));
    ++sample_index_;
    return out;
  }

 private:
  float oscillator(float frequency, int waveform = 0) {
    phase_ += frequency / static_cast<float>(sr_);
    phase_ -= std::floor(phase_);
    if (waveform == 1) return phase_ < 0.5f ? 1.0f : -1.0f;
    if (waveform == 2) return 2.0f * phase_ - 1.0f;
    return std::sin(kTwoPi * phase_);
  }

  Stereo pitchVoice(float x, PitchShifter& p, float gain) {
    const float y = p.process(x) * gain;
    return {y, y};
  }

  Stereo chorus(float l, float r, bool wide) {
    delay_l_.push(l);
    delay_r_.push(r);
    const float t = static_cast<float>(sample_index_) / sr_;
    const float depth = (4.0f + 9.0f * amount_) * sr_ / 1000.0f;
    const float base = (13.0f + (wide ? 10.0f : 4.0f) * amount_) * sr_ / 1000.0f;
    const float a = delay_l_.read(base + depth * (0.5f + 0.5f * std::sin(kTwoPi * 0.27f * t)));
    const float b = delay_r_.read(base * 1.35f + depth * (0.5f + 0.5f * std::sin(kTwoPi * 0.41f * t + 1.9f)));
    const float c = delay_l_.read(base * 1.8f + depth * 0.7f * (0.5f + 0.5f * std::sin(kTwoPi * 0.17f * t + 3.1f)));
    return {0.52f * l + 0.34f * a + 0.20f * b,
            0.52f * r + 0.34f * b + 0.20f * c};
  }

  float voiceDucking(float x) {
    const float instant = std::min(1.0f, std::fabs(x) * 7.0f);
    voice_envelope_ = std::max(instant, voice_envelope_ * 0.99935f);
    return 1.0f - (0.36f + 0.20f * amount_) * voice_envelope_;
  }

  Stereo chorusWithAsset(float l, float r, Stereo asset, bool has_asset) {
    if (!has_asset) return chorus(l, r, false);
    const float mono = 0.5f * (l + r);

    // The choir asset contains an original four-chord melody. Use it as a
    // vocoder carrier: the recording supplies words and articulation, while
    // the carrier supplies the actual sung notes. This is intentionally not
    // a dry voice laid over a choir bed.
    const float carrier = std::tanh(0.5f * (asset.l + asset.r) * 6.0f);
    const float articulated = vocoder_.process(mono, carrier, 3.5f, 105.0f);
    // A vocoder needs a separate unvoiced path for consonants: without it the
    // melody is audible but the words disappear. Only the high-frequency
    // articulation is restored; pitched vowels still come from the carrier.
    const float consonants = choir_consonants_.process(mono);
    const float sung =
        std::tanh(articulated * 14.0f + consonants * 0.42f) * 0.58f;
    const Stereo tuned_voice = chorus(sung, sung, true);

    // Keep a clearly intelligible lead in front of the vocoder. Two quieter
    // pitch-shifted copies turn it into a sung ensemble instead of restoring
    // the untouched speaking voice that the original implementation exposed.
    const float lower_harmony = many_low_.process(mono);
    const float upper_harmony = many_high_.process(mono);
    const float lead = std::tanh(
        (0.68f * mono + 0.18f * lower_harmony + 0.14f * upper_harmony) *
        1.18f);
    const Stereo lead_voice{
        clampf(lead + 0.07f * lower_harmony),
        clampf(lead + 0.07f * upper_harmony),
    };

    const float duck = voiceDucking(mono);
    const float bed = (0.006f + 0.012f * amount_) * duck;
    const float room_l = reverb_.process(asset.l, 0.62f);
    const float room_r = reverb_.process(asset.r, 0.67f);
    return {
        clampf(0.56f * tuned_voice.l + 0.78f * lead_voice.l +
               bed * (0.76f * asset.l + 0.24f * room_l)),
        clampf(0.56f * tuned_voice.r + 0.78f * lead_voice.r +
               bed * (0.76f * asset.r - 0.24f * room_r))};
  }

  Stereo ambienceAsset(float x, Stereo asset, int effect_id) {
    const float duck = voiceDucking(x);
    float voice_gain = 0.70f;
    float bed_gain = 0.50f;
    switch (effect_id) {
      case 26: voice_gain = 0.72f; bed_gain = 0.58f; break;
      case 27: voice_gain = 0.72f; bed_gain = 0.60f; break;
      case 28: voice_gain = 0.66f; bed_gain = 0.53f; break;
      case 29: voice_gain = 0.70f; bed_gain = 0.52f; break;
      case 30: voice_gain = 0.72f; bed_gain = 0.52f; break;
      case 32: voice_gain = 0.76f; bed_gain = 0.48f; break;
      case 34: voice_gain = 0.74f; bed_gain = 0.52f; break;
      case 36: voice_gain = 0.67f; bed_gain = 0.62f; break;
      default: break;
    }
    const float gain = bed_gain * (0.55f + 0.45f * amount_) * duck;
    return {clampf(voice_gain * x + gain * asset.l),
            clampf(voice_gain * x + gain * asset.r)};
  }

  Stereo robot(float x, bool super) {
    if (!super) {
      // A broad, low-pitched carrier supplies the monotone metallic body. A
      // little noise prevents the filter bank from collapsing into an audible
      // pure whistle and gives consonants enough excitation.
      const float fundamental = 92.0f + 10.0f * amount_;
      const float carrier =
          0.38f * oscillator(fundamental, 2) +
          0.22f * oscillator(fundamental * 2.01f, 1) +
          0.18f * oscillator(fundamental * 3.02f, 2) +
          0.22f * rng_.uniform();
      float articulated = vocoder_.process(x, carrier, 2.2f, 58.0f);
      articulated = robot_output_highpass_.process(articulated);
      const float consonants = robot_consonants_.process(x);
      const float clarity = robot_clarity_lowpass_.process(
          robot_clarity_highpass_.process(x));
      const float robot_body = std::tanh(articulated * 6.4f) * 0.62f;
      // The band-limited lead guarantees understandable words. It remains
      // subordinate to the fixed-pitch body, so the result is robotic rather
      // than a megaphone or an untouched voice.
      const float y = clampf(0.72f * robot_body + 0.58f * clarity +
                             0.12f * consonants);
      short_delay_.push(y);
      const float side = short_delay_.read(sr_ * 0.0042f);
      return {clampf(1.08f * y + 0.07f * side),
              clampf(1.08f * y - 0.07f * side)};
    }

    const float f = super ? 92.0f : 58.0f;
    const float saw = oscillator(f, super ? 1 : 2);
    const float excitation = super ? 0.65f * saw + 0.35f * oscillator(f * 2.01f, 2)
                                   : saw;
    float y = vocoder_.process(x, excitation, super ? 4.0f : 7.0f,
                               super ? 75.0f : 120.0f);
    const float ring = x * std::sin(kTwoPi * f * sample_index_ / sr_);
    y = std::tanh((y * (super ? 3.4f : 2.5f) + ring * (super ? 0.45f : 0.22f)));
    const float side = shortComb(y, super ? 0.011f : 0.018f, 0.52f);
    return {0.78f * y + 0.22f * side, 0.78f * y - 0.22f * side};
  }

  Stereo oldRadio(float x, Stereo asset, bool has_asset) {
    // Voice band, transformer-like saturation and wow/flutter. A pre-rendered
    // static/crackle bed is preferred; deterministic synthesis remains fallback.
    float y = hp_.process(x);
    y = lp_.process(y);
    y = std::tanh(y * (2.2f + 2.8f * amount_));
    short_delay_.push(y);
    const float t = static_cast<float>(sample_index_) / sr_;
    const float wow = (2.5f + 8.0f * amount_) * (0.5f + 0.5f * std::sin(kTwoPi * 0.72f * t));
    y = 0.68f * y + 0.32f * short_delay_.read(wow);
    float noise = rng_.uniform() * (0.012f + 0.028f * amount_);
    const bool crackle = rng_.positive() > (0.99955f - 0.00020f * amount_);
    if (crackle) crackle_env_ = 1.0f;
    crackle_env_ *= 0.86f;
    noise += rng_.uniform() * crackle_env_ * (0.08f + 0.22f * amount_);
    if (has_asset) {
      const float duck = voiceDucking(x);
      const float bed = (0.055f + 0.095f * amount_) * duck;
      y = clampf(y * 0.94f + bed * 0.5f * (asset.l + asset.r));
      return {clampf(y + bed * 0.18f * asset.l),
              clampf(y + bed * 0.18f * asset.r)};
    }
    y = clampf((y * 0.92f + noise) * 0.92f);
    return {y, y};
  }

  Stereo alien(float x) {
    const float t = static_cast<float>(sample_index_) / sr_;
    const float low = pitch_low_.process(x);
    const float carrier =
        0.56f * oscillator(126.0f + 18.0f * std::sin(kTwoPi * 0.37f * t), 2) +
        0.29f * oscillator(251.0f, 1) + 0.15f * rng_.uniform();
    const float vocoded = vocoder_.process(x, carrier, 3.5f, 82.0f);
    const float ring = x * std::sin(kTwoPi * (71.0f + 24.0f * amount_) * t);
    const float spectral =
        std::tanh((0.34f * low + 0.76f * vocoded + 0.24f * ring) * 2.6f);
    const float echo =
        shortComb(spectral, 0.021f + 0.023f * amount_, 0.67f);
    return {clampf(spectral + 0.31f * echo),
            clampf(spectral - 0.27f * echo)};
  }

  Stereo monster(float x) {
    const float a = pitch_very_low_.process(x);
    const float b = pitch_low_.process(x);
    const float rumble = tone_low_.process(x) * 0.8f;
    const float y = std::tanh((0.54f * a + 0.38f * b + 0.22f * rumble) * 2.0f);
    return {y, y};
  }

  Stereo brightVoice(float x) {
    const float high = tone_high_.process(x);
    const float y = clampf(x * 0.84f + high * (0.45f + 0.45f * amount_));
    return {y, y};
  }

  Stereo darkVoice(float x) {
    const float low = tone_low_.process(x);
    const float shifted = pitch_low_.process(x);
    const float y = std::tanh((0.58f * x + 0.28f * shifted + 0.34f * low) * 1.25f);
    return {y, y};
  }

  Stereo talkingGuitar(float x, Stereo asset, bool has_asset) {
    const float base = 82.41f;
    const float pluck_phase = std::fmod(static_cast<float>(sample_index_) / sr_ * 3.1f, 1.0f);
    const float pluck = std::exp(-7.5f * pluck_phase);
    float carrier = has_asset
        ? 0.5f * (asset.l + asset.r)
        : 0.45f * oscillator(base, 2) +
              0.30f * oscillator(base * 1.498f, 2) +
              0.20f * oscillator(base * 2.01f, 2);
    if (!has_asset) carrier *= 0.55f + 0.45f * pluck;
    carrier = std::tanh(carrier * (has_asset ? 1.8f : 1.0f));
    float y = vocoder_.process(x, carrier, 5.0f, 95.0f);
    y = std::tanh(y * 3.2f);
    return {y * 0.94f, y * 0.86f};
  }

  Stereo mosquito(float x) {
    const float p = pitch_mosquito_.process(x);
    const float trem = 0.58f + 0.42f * std::sin(kTwoPi * 18.0f * sample_index_ / sr_);
    const float y = clampf(p * trem * 1.15f);
    return {y, y};
  }

  Stereo oneOfMany(float x) {
    const float c = x * 0.35f;
    const float lo = many_low_.process(x);
    const float hi = many_high_.process(x);
    const float far = many_far_.process(x);
    delay_l_.push(lo);
    delay_r_.push(hi);
    const float l = c + 0.31f * delay_l_.read(sr_ * 0.014f) + 0.25f * far;
    const float r = c + 0.31f * delay_r_.read(sr_ * 0.026f) + 0.25f * far;
    return {clampf(l), clampf(r)};
  }

  Stereo organVocoder(float x, Stereo asset, bool has_asset) {
    const float f = 110.0f;
    const float synthetic = 0.50f * oscillator(f) +
                            0.28f * oscillator(f * 2.0f) +
                            0.16f * oscillator(f * 3.0f) +
                            0.10f * oscillator(f * 4.0f);
    const float carrier = has_asset
        ? std::tanh(0.5f * (asset.l + asset.r) * 1.65f)
        : synthetic;
    float y = vocoder_.process(x, carrier, 9.0f, 160.0f);
    const float rev = reverb_.process(y, 0.52f);
    y = std::tanh((y + 0.25f * rev) * 2.2f);
    return {y, y};
  }

  Stereo warped(float l, float r) {
    delay_l_.push(l);
    delay_r_.push(r);
    const float t = static_cast<float>(sample_index_) / sr_;
    const float d1 = (4.0f + 22.0f * (0.5f + 0.5f * std::sin(kTwoPi * 0.13f * t))) * sr_ / 1000.0f;
    const float d2 = (8.0f + 31.0f * (0.5f + 0.5f * std::sin(kTwoPi * 0.21f * t + 1.4f))) * sr_ / 1000.0f;
    return {0.58f * l + 0.58f * delay_r_.read(d1),
            0.58f * r - 0.50f * delay_l_.read(d2)};
  }

  Stereo swirling(float l, float r) {
    delay_l_.push(l);
    delay_r_.push(r);
    const float t = static_cast<float>(sample_index_) / sr_;
    const float pan = std::sin(kTwoPi * (0.18f + 0.20f * amount_) * t);
    const float d = (3.0f + 10.0f * (0.5f + 0.5f * std::sin(kTwoPi * 0.31f * t))) * sr_ / 1000.0f;
    const float a = delay_l_.read(d), b = delay_r_.read(d * 1.37f);
    return {(0.50f + 0.28f * pan) * l + (0.45f - 0.20f * pan) * b,
            (0.50f - 0.28f * pan) * r + (0.45f + 0.20f * pan) * a};
  }

  Stereo vader(float x) {
    const float shifted = pitch_vader_.process(x);
    const float breath = hp_.process(rng_.uniform()) * (0.018f + 0.05f * amount_);
    const float y = std::tanh((0.82f * shifted + 0.23f * tone_low_.process(x) + breath) * 1.9f);
    return {y, y};
  }

  Stereo metallic(float x) {
    const float ring = x * (0.65f * std::sin(kTwoPi * 97.0f * sample_index_ / sr_) +
                            0.35f * std::sin(kTwoPi * 173.0f * sample_index_ / sr_));
    const float comb = shortComb(ring, 0.008f, 0.68f);
    const float y = std::tanh((0.35f * x + ring + 0.45f * comb) * 1.8f);
    return {y, -0.82f * y};
  }

  Stereo songbird(float x) {
    const float p = pitch_songbird_.process(x);
    const float trill = 0.82f + 0.18f * std::sin(kTwoPi * 7.4f * sample_index_ / sr_);
    const float y = clampf(p * trill * 1.08f);
    return {y, y};
  }

  Stereo exterminator(float x) {
    const float pulse = oscillator(74.0f + 18.0f * amount_, 1);
    float y = vocoder_.process(x, pulse + 0.25f * oscillator(148.0f, 2), 2.5f, 55.0f);
    const float gate = 0.52f + 0.48f * (std::sin(kTwoPi * 24.0f * sample_index_ / sr_) > 0.0f ? 1.0f : 0.0f);
    y = std::tanh(y * gate * 4.0f);
    return {y, y};
  }

  Stereo rainThunder(float x) {
    const float rain = 0.040f * rng_.uniform() + 0.016f * tone_high_.process(rng_.uniform());
    if (rng_.positive() > 0.999985f) thunder_env_ = 1.0f;
    thunder_env_ *= 0.99972f;
    const float thunder = tone_low_.process(rng_.uniform()) * thunder_env_ * 0.85f;
    return {clampf(0.74f * x + (rain + thunder) * amount_),
            clampf(0.74f * x + (rain * 0.91f + thunder) * amount_)};
  }

  Stereo jungle(float x) {
    const float t = static_cast<float>(sample_index_) / sr_;
    float birds = 0.0f;
    const float cycle = std::fmod(t, 2.7f);
    if (cycle < 0.22f) birds = std::sin(kTwoPi * (1700.0f + 900.0f * cycle / 0.22f) * t) * (1.0f - cycle / 0.22f);
    const float ambience = 0.025f * tone_high_.process(rng_.uniform()) + 0.08f * birds;
    return {clampf(0.76f * x + ambience * amount_), clampf(0.76f * x + ambience * 0.86f * amount_)};
  }

  Stereo crowd(float x) {
    // A real ambience bed, deliberately different from "one voice in many".
    const float t = static_cast<float>(sample_index_) / sr_;
    const float voice_envelope = std::min(1.0f, std::fabs(x) * 7.0f);
    const float babble_a =
        tone_low_.process(rng_.uniform()) *
        (0.055f + 0.025f * std::sin(kTwoPi * 0.31f * t));
    const float babble_b =
        bp_.process(rng_.uniform()) *
        (0.040f + 0.020f * std::sin(kTwoPi * 0.47f * t + 1.7f));
    const float distant_voices =
        (0.055f * std::sin(kTwoPi * 173.0f * t) +
         0.043f * std::sin(kTwoPi * 229.0f * t + 0.8f) +
         0.031f * std::sin(kTwoPi * 311.0f * t + 2.1f)) *
        (0.35f + 0.65f * voice_envelope);
    const float room = reverb_.process(babble_a + babble_b + distant_voices,
                                       0.74f);
    return {clampf(0.68f * x + (babble_a + distant_voices + 0.55f * room) *
                                  (0.55f + 0.45f * amount_)),
            clampf(0.68f * x + (babble_b - 0.78f * distant_voices -
                                0.48f * room) *
                                  (0.55f + 0.45f * amount_))};
  }

  Stereo slotMachines(float x) {
    const float t = static_cast<float>(sample_index_) / sr_;
    float bell = 0.0f;
    const float p = std::fmod(t, 0.73f);
    if (p < 0.08f) bell = std::sin(kTwoPi * (1100.0f + 700.0f * p / 0.08f) * t) * std::exp(-32.0f * p);
    return {clampf(0.72f * x + 0.25f * bell * amount_), clampf(0.72f * x + 0.21f * bell * amount_)};
  }

  Stereo traffic(float x) {
    const float t = static_cast<float>(sample_index_) / sr_;
    const float engine = 0.055f * std::sin(kTwoPi * (62.0f + 9.0f * std::sin(kTwoPi * 0.09f * t)) * t);
    const float road = 0.025f * tone_low_.process(rng_.uniform());
    return {clampf(0.78f * x + (engine + road) * amount_), clampf(0.78f * x + (engine - road) * amount_)};
  }

  Stereo spaceship(float x) {
    const float t = static_cast<float>(sample_index_) / sr_;
    const float hum = 0.11f * std::sin(kTwoPi * (74.0f + 12.0f * std::sin(kTwoPi * 0.16f * t)) * t);
    const float sweep = 0.07f * std::sin(kTwoPi * (420.0f + 300.0f * std::sin(kTwoPi * 0.07f * t)) * t);
    const Stereo w = warped(x, x);
    return {clampf(0.54f * w.l + (hum + sweep) * amount_), clampf(0.54f * w.r + (hum - sweep) * amount_)};
  }

  Stereo cricket(float x) {
    const float t = static_cast<float>(sample_index_) / sr_;
    const float pulse = std::sin(kTwoPi * 23.0f * t) > 0.55f ? 1.0f : 0.0f;
    const float chirp = std::sin(kTwoPi * (3900.0f + 350.0f * std::sin(kTwoPi * 4.0f * t)) * t) * pulse * 0.11f;
    return {clampf(0.80f * x + chirp * amount_), clampf(0.80f * x + chirp * 0.83f * amount_)};
  }

  Stereo siren(float x) {
    const float t = static_cast<float>(sample_index_) / sr_;
    const float freq = 670.0f + 310.0f * std::sin(kTwoPi * 0.63f * t);
    const float s = 0.16f * std::sin(kTwoPi * freq * t);
    return {clampf(0.73f * x + s * amount_), clampf(0.73f * x + s * 0.92f * amount_)};
  }

  Stereo sleighBells(float x) {
    if (rng_.positive() > 0.9991f) bell_env_ = 1.0f;
    bell_env_ *= 0.992f;
    const float t = static_cast<float>(sample_index_) / sr_;
    const float bell = bell_env_ * (0.12f * std::sin(kTwoPi * 3100.0f * t) + 0.08f * std::sin(kTwoPi * 4870.0f * t));
    return {clampf(0.77f * x + bell * amount_), clampf(0.77f * x + bell * 0.88f * amount_)};
  }

  Stereo dj(float x) {
    const float t = static_cast<float>(sample_index_) / sr_;
    const float gate = 0.62f + 0.38f * (std::sin(kTwoPi * 3.6f * t) > -0.25f ? 1.0f : 0.0f);
    const float scratch = shortComb(x, 0.045f + 0.025f * std::sin(kTwoPi * 0.7f * t), 0.74f);
    return {clampf(gate * (0.58f * x + 0.52f * scratch)), clampf(gate * (0.58f * x - 0.42f * scratch))};
  }

  Stereo applause(float x) {
    if (rng_.positive() > 0.9965f) applause_env_ = 1.0f;
    applause_env_ *= 0.94f;
    const float clap = rng_.uniform() * applause_env_ * 0.24f;
    const float room = reverb_.process(clap, 0.70f);
    return {clampf(0.72f * x + (clap + 0.55f * room) * amount_), clampf(0.72f * x + (clap - 0.45f * room) * amount_)};
  }

  Stereo badMelody(float x) {
    const float t = static_cast<float>(sample_index_) / sr_;
    const std::array<float, 5> notes{261.63f, 311.13f, 369.99f, 440.0f, 277.18f};
    const int n = static_cast<int>(t * 3.2f) % static_cast<int>(notes.size());
    const float env = std::min(1.0f, std::fabs(x) * 8.0f);
    const float tone = std::sin(kTwoPi * notes[n] * t) * env * 0.22f;
    return {clampf(0.75f * x + tone * amount_), clampf(0.75f * x + tone * 0.90f * amount_)};
  }

  Stereo badHarmony(float x) {
    const float very_low = pitch_very_low_.process(x);
    const float high = pitch_very_high_.process(x);
    const float off = many_far_.process(x);
    const float t = static_cast<float>(sample_index_) / sr_;
    const float beating = x * std::sin(kTwoPi * 37.0f * t);
    delay_l_.push(very_low);
    delay_r_.push(high);
    return {clampf(0.20f * x + 0.43f * delay_l_.read(sr_ * 0.019f) -
                   0.39f * high + 0.31f * off + 0.20f * beating),
            clampf(0.20f * x - 0.37f * very_low +
                   0.45f * delay_r_.read(sr_ * 0.033f) -
                   0.28f * off - 0.18f * beating)};
  }

  Stereo warmVoice(float x) {
    const float low = tone_low_.process(x);
    const float y = std::tanh((0.88f * x + 0.23f * low) * (1.15f + 0.55f * amount_));
    return {y, y};
  }

  Stereo turtle(float x) {
    const float p = pitch_turtle_.process(x);
    const float t = static_cast<float>(sample_index_) / sr_;
    const float slow = 0.88f + 0.12f * std::sin(kTwoPi * 1.5f * t);
    const float y = std::tanh(p * slow * 1.45f);
    return {y, y};
  }

  Stereo haunting(float x) {
    const float low = pitch_low_.process(x);
    const float rev = reverb_.process(low, 0.72f);
    const float whisper = hp_.process(rng_.uniform()) * std::min(0.18f, std::fabs(x) * 0.5f);
    return {clampf(0.43f * low + 0.65f * rev + whisper), clampf(0.43f * low - 0.58f * rev + whisper)};
  }

  float shortComb(float x, float delay_seconds, float feedback) {
    short_delay_.push(x);
    return short_delay_.read(std::clamp(delay_seconds, 0.001f, 0.22f) * sr_) * feedback;
  }

  int id_;
  float amount_;
  int sr_;
  uint64_t sample_index_ = 0;
  float phase_ = 0.0f;
  float voice_envelope_ = 0.0f;
  float crackle_env_ = 0.0f, thunder_env_ = 0.0f, bell_env_ = 0.0f,
        applause_env_ = 0.0f;
  DelayLine delay_l_, delay_r_, short_delay_;
  SimpleReverb reverb_;
  PitchShifter pitch_low_, pitch_very_low_, pitch_high_, pitch_very_high_,
      pitch_vader_, pitch_mosquito_, pitch_songbird_, pitch_turtle_,
      many_low_, many_high_, many_far_;
  FilterBankVocoder vocoder_;
  FastRng rng_;
  Biquad hp_, lp_, bp_, tone_low_, tone_high_, choir_consonants_,
      robot_consonants_, robot_output_highpass_, robot_clarity_highpass_,
      robot_clarity_lowpass_;
};

bool processReverse(FILE* in, FILE* out, int channels) {
  if (std::fseek(in, 0, SEEK_END) != 0) return false;
  const long bytes = std::ftell(in);
  if (bytes < 0) return false;
  const long frame_bytes = static_cast<long>(channels * sizeof(float));
  if (frame_bytes <= 0 || bytes % frame_bytes != 0) return false;
  const long total_frames = bytes / frame_bytes;
  std::vector<float> buffer(static_cast<size_t>(kBlockFrames * channels));
  long remaining = total_frames;
  while (remaining > 0) {
    if (g_cancel_requested.load(std::memory_order_relaxed)) return false;
    const int frames = static_cast<int>(std::min<long>(remaining, kBlockFrames));
    const long start = remaining - frames;
    if (std::fseek(in, start * frame_bytes, SEEK_SET) != 0) return false;
    if (std::fread(buffer.data(), frame_bytes, frames, in) != static_cast<size_t>(frames)) return false;
    for (int i = 0; i < frames / 2; ++i) {
      for (int c = 0; c < channels; ++c) {
        std::swap(buffer[(i * channels) + c], buffer[((frames - 1 - i) * channels) + c]);
      }
    }
    if (std::fwrite(buffer.data(), frame_bytes, frames, out) != static_cast<size_t>(frames)) return false;
    remaining -= frames;
  }
  return true;
}

void fft(std::vector<std::complex<float>>& values, bool inverse) {
  const size_t size = values.size();
  for (size_t i = 1, j = 0; i < size; ++i) {
    size_t bit = size >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) std::swap(values[i], values[j]);
  }
  for (size_t length = 2; length <= size; length <<= 1) {
    const float angle = (inverse ? kTwoPi : -kTwoPi) /
                        static_cast<float>(length);
    const std::complex<float> step(std::cos(angle), std::sin(angle));
    for (size_t start = 0; start < size; start += length) {
      std::complex<float> phase(1.0f, 0.0f);
      const size_t half = length >> 1;
      for (size_t offset = 0; offset < half; ++offset) {
        const auto even = values[start + offset];
        const auto odd = values[start + offset + half] * phase;
        values[start + offset] = even + odd;
        values[start + offset + half] = even - odd;
        phase *= step;
      }
    }
  }
  if (inverse) {
    const float scale = 1.0f / static_cast<float>(size);
    for (auto& value : values) value *= scale;
  }
}

bool processSpectralRobot(FILE* in, FILE* out, int effect_id, float amount,
                          int sample_rate, int channels) {
  constexpr int frame_size = 1024;
  constexpr int hop_size = 256;
  constexpr int leading_padding = frame_size - hop_size;
  constexpr float robot_pitch_hz = 95.0f;
  constexpr float robot_pitch_ratio = 1.12f;

  if (std::fseek(in, 0, SEEK_END) != 0) return false;
  const long bytes = std::ftell(in);
  const long frame_bytes = static_cast<long>(channels * sizeof(float));
  if (bytes <= 0 || frame_bytes <= 0 || bytes % frame_bytes != 0 ||
      std::fseek(in, 0, SEEK_SET) != 0) {
    return false;
  }
  const int64_t total_frames = bytes / frame_bytes;
  const int64_t iterations =
      (total_frames + leading_padding + hop_size - 1) / hop_size;

  std::vector<float> input_window(frame_size, 0.0f);
  std::vector<float> overlap(frame_size, 0.0f);
  std::vector<float> normalization(frame_size, 0.0f);
  std::vector<float> interleaved(static_cast<size_t>(hop_size * channels),
                                 0.0f);
  std::vector<float> output_frame(static_cast<size_t>(hop_size * channels),
                                  0.0f);
  std::vector<float> window(frame_size);
  std::vector<std::complex<float>> spectrum(frame_size);
  PitchShifter pitch_lift(static_cast<float>(sample_rate), robot_pitch_ratio);
  for (int i = 0; i < frame_size; ++i) {
    window[i] = std::sqrt(0.5f -
                          0.5f * std::cos(kTwoPi * i / (frame_size - 1)));
  }

  int64_t input_read = 0;
  for (int64_t iteration = 0; iteration < iterations; ++iteration) {
    if (g_cancel_requested.load(std::memory_order_relaxed)) return false;
    std::move(input_window.begin() + hop_size, input_window.end(),
              input_window.begin());
    std::fill(input_window.end() - hop_size, input_window.end(), 0.0f);

    const int frames_to_read = static_cast<int>(
        std::min<int64_t>(hop_size, total_frames - input_read));
    if (frames_to_read > 0) {
      const size_t samples_to_read =
          static_cast<size_t>(frames_to_read * channels);
      if (std::fread(interleaved.data(), sizeof(float), samples_to_read, in) !=
          samples_to_read) {
        return false;
      }
      for (int frame = 0; frame < frames_to_read; ++frame) {
        const float left = interleaved[frame * channels];
        const float right =
            channels > 1 ? interleaved[frame * channels + 1] : left;
        input_window[frame_size - hop_size + frame] =
            0.5f * (left + right);
      }
      input_read += frames_to_read;
    }

    for (int i = 0; i < frame_size; ++i) {
      spectrum[i] = {input_window[i] * window[i], 0.0f};
    }
    fft(spectrum, false);
    for (int bin = 0; bin <= frame_size / 2; ++bin) {
      const float comb = 0.25f +
                         0.75f * std::pow(std::fabs(std::cos(
                             kPi * bin * sample_rate /
                             (2.0f * frame_size * robot_pitch_hz))),
                                         8.0f);
      const float magnitude = std::abs(spectrum[bin]) * comb;
      spectrum[bin] = {magnitude, 0.0f};
      if (bin > 0 && bin < frame_size / 2) {
        spectrum[frame_size - bin] = {magnitude, 0.0f};
      }
    }
    fft(spectrum, true);
    for (int i = 0; i < frame_size; ++i) {
      overlap[i] += spectrum[i].real() * window[i];
      normalization[i] += window[i] * window[i];
    }

    const int64_t block_start = iteration * hop_size - leading_padding;
    int frames_written = 0;
    for (int i = 0; i < hop_size; ++i) {
      const int64_t absolute_frame = block_start + i;
      if (absolute_frame < 0 || absolute_frame >= total_frames) continue;
      const float normalized = normalization[i] > 1.0e-5f
                                   ? overlap[i] / normalization[i]
                                   : 0.0f;
      const float pitched = pitch_lift.process(normalized);
      const float depth = effect_id == 3
                              ? 0.55f + 0.20f * amount
                              : 0.10f + 0.10f * amount;
      const float tremolo =
          1.0f - depth * 0.5f + depth * 0.5f *
                                         std::sin(kTwoPi * 30.0f *
                                                  absolute_frame /
                                                  sample_rate);
      const float y = clampf(pitched * 4.0f * tremolo, -0.88f, 0.88f);
      const size_t base = static_cast<size_t>(frames_written * channels);
      output_frame[base] = y;
      if (channels > 1) output_frame[base + 1] = y;
      for (int channel = 2; channel < channels; ++channel) {
        output_frame[base + channel] = y;
      }
      ++frames_written;
    }
    if (frames_written > 0 &&
        std::fwrite(output_frame.data(), frame_bytes, frames_written, out) !=
            static_cast<size_t>(frames_written)) {
      return false;
    }

    std::move(overlap.begin() + hop_size, overlap.end(), overlap.begin());
    std::fill(overlap.end() - hop_size, overlap.end(), 0.0f);
    std::move(normalization.begin() + hop_size, normalization.end(),
              normalization.begin());
    std::fill(normalization.end() - hop_size, normalization.end(), 0.0f);
  }
  return true;
}

bool processNormal(FILE* in, FILE* out, const char* asset_path,
                   int effect_id, float amount, int sample_rate, int channels) {
  DspProcessor processor(effect_id, amount, sample_rate);
  AssetLoop asset;
  const bool has_asset = asset.load(asset_path, channels);
  uint64_t frame_index = 0;
  std::vector<float> input(static_cast<size_t>(kBlockFrames * channels));
  std::vector<float> output(static_cast<size_t>(kBlockFrames * channels));
  while (true) {
    if (g_cancel_requested.load(std::memory_order_relaxed)) return false;
    const size_t samples = std::fread(input.data(), sizeof(float), input.size(), in);
    if (samples == 0) {
      if (std::ferror(in)) return false;
      break;
    }
    if (samples % static_cast<size_t>(channels) != 0) return false;
    const size_t frames = samples / channels;
    for (size_t i = 0; i < frames; ++i) {
      const float l = input[i * channels];
      const float r = channels > 1 ? input[i * channels + 1] : l;
      const Stereo asset_sample = has_asset ? asset.sample(frame_index) : Stereo{};
      const Stereo y = processor.process(l, r, asset_sample, has_asset);
      ++frame_index;
      output[i * channels] = std::isfinite(y.l) ? y.l : 0.0f;
      if (channels > 1) output[i * channels + 1] = std::isfinite(y.r) ? y.r : 0.0f;
      for (int c = 2; c < channels; ++c) output[i * channels + c] = 0.5f * (y.l + y.r);
    }
    if (std::fwrite(output.data(), sizeof(float), samples, out) != samples) return false;
    if (samples < input.size()) break;
  }
  return true;
}

}  // namespace

extern "C" int32_t sonarpad_dsp_process_file(
    const char* input_path, const char* asset_path, const char* output_path,
    int32_t effect_id, float amount, int32_t sample_rate, int32_t channels) {
  g_last_error.clear();
  g_cancel_requested.store(false, std::memory_order_relaxed);
  try {
    if (!input_path || !output_path || input_path[0] == '\0' ||
        output_path[0] == '\0') {
      g_last_error = "Percorso DSP non valido.";
      return 1;
    }
    if (std::strcmp(input_path, output_path) == 0) {
      g_last_error = "Ingresso e uscita DSP devono essere file diversi.";
      return 1;
    }
    if (sample_rate < 8000 || sample_rate > 192000 || channels < 1 ||
        channels > 8) {
      g_last_error = "Formato PCM non supportato.";
      return 2;
    }
    if (!std::isfinite(amount)) amount = 0.5f;

    FILE* in = std::fopen(input_path, "rb");
    if (!in) {
      g_last_error =
          std::string("Impossibile aprire l'audio DSP in ingresso: ") +
          std::strerror(errno);
      return 3;
    }
    if (std::fseek(in, 0, SEEK_END) != 0) {
      g_last_error = "Impossibile verificare il PCM DSP in ingresso.";
      std::fclose(in);
      return 3;
    }
    const long input_bytes = std::ftell(in);
    const long frame_bytes = static_cast<long>(channels * sizeof(float));
    if (input_bytes <= 0 || frame_bytes <= 0 ||
        input_bytes % frame_bytes != 0 || std::fseek(in, 0, SEEK_SET) != 0) {
      g_last_error = "Il PCM DSP è vuoto o contiene un fotogramma incompleto.";
      std::fclose(in);
      return 3;
    }

    FILE* out = std::fopen(output_path, "wb");
    if (!out) {
      g_last_error =
          std::string("Impossibile creare l'audio DSP in uscita: ") +
          std::strerror(errno);
      std::fclose(in);
      return 4;
    }

    bool ok = false;
    if (effect_id == 14) {
      ok = processReverse(in, out, channels);
    } else if (effect_id == 2 || effect_id == 3) {
      ok = processSpectralRobot(in, out, effect_id, amount, sample_rate,
                                channels);
    } else if (effect_id >= 1 && effect_id <= 41 && effect_id != 20) {
      // ID 20 (fan) was deliberately merged with the existing helicopter
      // effect during the perceptual deduplication pass.
      ok = processNormal(in, out, asset_path, effect_id, amount, sample_rate, channels);
    } else {
      g_last_error = "Effetto DSP sconosciuto o non pubblicato.";
    }

    if (std::fclose(out) != 0) {
      ok = false;
      if (g_last_error.empty()) {
        g_last_error = "Scrittura finale del file DSP non riuscita.";
      }
    }
    std::fclose(in);

    if (!ok) {
      if (g_cancel_requested.load(std::memory_order_relaxed)) {
        g_last_error = "Elaborazione DSP annullata.";
      } else if (g_last_error.empty()) {
        g_last_error =
            "Elaborazione DSP non riuscita o file PCM incompleto.";
      }
      std::remove(output_path);
      return 5;
    }
    return 0;
  } catch (const std::exception& error) {
    g_last_error = std::string("Errore DSP C++: ") + error.what();
  } catch (...) {
    g_last_error = "Errore DSP C++ non identificato.";
  }
  if (output_path) std::remove(output_path);
  return 6;
}

extern "C" void sonarpad_dsp_cancel(void) {
  g_cancel_requested.store(true, std::memory_order_relaxed);
}

extern "C" const char* sonarpad_dsp_last_error(void) {
  return g_last_error.c_str();
}

extern "C" int32_t sonarpad_dsp_version(void) { return 2; }
