#ifndef SONARPAD_AUDIO_DSP_H_
#define SONARPAD_AUDIO_DSP_H_

#include <stdint.h>

#if defined(_WIN32)
#define SONARPAD_DSP_EXPORT __declspec(dllexport)
#else
#define SONARPAD_DSP_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

SONARPAD_DSP_EXPORT int32_t sonarpad_dsp_process_file(
    const char* input_path,
    const char* asset_path,
    const char* output_path,
    int32_t effect_id,
    float amount,
    int32_t sample_rate,
    int32_t channels);

SONARPAD_DSP_EXPORT void sonarpad_dsp_cancel(void);
SONARPAD_DSP_EXPORT const char* sonarpad_dsp_last_error(void);
SONARPAD_DSP_EXPORT int32_t sonarpad_dsp_version(void);

#ifdef __cplusplus
}
#endif

#endif
