# Original Sonarpad effect asset generator. Requires numpy, scipy and ffmpeg.
import os, math, subprocess
from pathlib import Path
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve
from scipy.io import wavfile

SR=44100
OUT=str(Path(__file__).resolve().parents[1] / 'assets' / 'audio' / 'effect_sources')
os.makedirs(OUT, exist_ok=True)
rng=np.random.default_rng(20260728)

def norm(x, peak=0.88):
    x=np.asarray(x, np.float64)
    m=np.max(np.abs(x)) or 1.0
    return (x/m*peak).astype(np.float32)

def stereo(x, width=0.12):
    x=np.asarray(x)
    if x.ndim==2: return x
    d=max(1,int(SR*0.013))
    r=np.roll(x,d)* (1-width) + np.roll(x,-d)*width
    return np.stack([x,r],axis=1)

def filt(x, lo=None, hi=None, order=4):
    if lo and hi: sos=butter(order,[lo,hi],btype='bandpass',fs=SR,output='sos')
    elif lo: sos=butter(order,lo,btype='highpass',fs=SR,output='sos')
    elif hi: sos=butter(order,hi,btype='lowpass',fs=SR,output='sos')
    else: return x
    return sosfilt(sos,x)

def pink(n):
    # Voss-like colored noise through cascaded lowpasses.
    w=rng.normal(0,1,n)
    a=filt(w,hi=7000,order=2)
    b=filt(w,hi=1800,order=2)
    c=filt(w,hi=450,order=2)
    return 0.55*a+0.30*b+0.15*c

def add_event(buf, start, sig, pan=0.0, gain=1.0):
    i=int(start*SR); n=min(len(sig), len(buf)-i)
    if n<=0:return
    gl=math.sqrt((1-pan)*0.5)*gain
    gr=math.sqrt((1+pan)*0.5)*gain
    buf[i:i+n,0]+=sig[:n]*gl
    buf[i:i+n,1]+=sig[:n]*gr

def exp_env(n, attack=0.002, decay=0.2):
    t=np.arange(n)/SR
    return (1-np.exp(-t/max(attack,1e-5)))*np.exp(-t/max(decay,1e-5))

def tone(freq,dur,amp=1.0, harmonics=(1,), detune=0.0):
    n=int(dur*SR); t=np.arange(n)/SR
    y=np.zeros(n)
    for k,h in enumerate(harmonics):
        y += (1/(k+1))*np.sin(2*np.pi*freq*h*(1+detune)*t + rng.random()*2*np.pi)
    return amp*y/ max(1,len(harmonics)**0.5)

def room(sig, decay=0.8):
    # Sparse synthetic room impulse used only to make the pre-rendered assets coherent.
    ir=np.zeros(int(SR*1.2)); ir[0]=1
    for d,g in [(0.031,.45),(0.047,.32),(0.073,.24),(0.119,.18),(0.181,.12),(0.277,.08)]:
        ir[int(d*SR)]=g
    ir += rng.normal(0,1,len(ir))*np.exp(-np.arange(len(ir))/(SR*decay))*0.012
    return fftconvolve(sig,ir,mode='full')[:len(sig)]

def write_mp3(name, data, title, bitrate='96k'):
    data=norm(data)
    wav=os.path.join(OUT,name.replace('.mp3','.wav'))
    wavfile.write(wav,SR,(data*32767).astype(np.int16))
    mp3=os.path.join(OUT,name)
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',wav,
                    '-c:a','libmp3lame','-b:a',bitrate,'-ar',str(SR),
                    '-metadata',f'title={title}','-metadata','artist=Sonarpad DSP Assets',mp3],check=True)
    os.remove(wav)
    print(name, os.path.getsize(mp3))

# Choir vowel pad: layered formant-rich voices, no words.
def choir_asset(dur=16):
    n=int(dur*SR); t=np.arange(n)/SR; out=np.zeros((n,2))
    chords=[[130.81,164.81,196.00],[146.83,185.00,220.00],[110.00,164.81,220.00],[130.81,196.00,261.63]]
    seg=dur/len(chords)
    for ci,ch in enumerate(chords):
        s0=int(ci*seg*SR); s1=min(n,int((ci+1)*seg*SR)); tt=np.arange(s1-s0)/SR
        env=np.sin(np.pi*np.clip(tt/seg,0,1))**0.35
        voice=np.zeros(len(tt))
        for f in ch:
            for det in (-0.006,0,0.005):
                phase=rng.random()*2*np.pi
                raw=sum((1/h)*np.sin(2*np.pi*f*h*(1+det)*tt+phase) for h in range(1,9))
                # vowel-like spectral emphasis
                raw=filt(raw,hi=4200,order=2)
                voice += raw
        voice/=18
        voice=0.75*filt(voice,lo=180,hi=3200,order=2)+0.25*filt(voice,lo=700,hi=1500,order=2)
        out[s0:s1,0]+=voice*env
        out[s0:s1,1]+=np.roll(voice,int(.009*SR))*env
    out[:,0]=room(out[:,0],1.4); out[:,1]=room(out[:,1],1.6)
    return out

# Guitar carrier: Karplus-Strong chord/arpeggio, deliberately broadband for vocoder.
def karplus(freq,dur,decay=.996):
    n=int(dur*SR); p=max(2,int(SR/freq)); ring=rng.uniform(-1,1,p); y=np.zeros(n)
    idx=0
    for i in range(n):
        y[i]=ring[idx]
        nxt=(idx+1)%p
        ring[idx]=decay*0.5*(ring[idx]+ring[nxt])
        idx=nxt
    return y

def guitar_asset(dur=16):
    out=np.zeros((int(dur*SR),2)); notes=[82.41,110,146.83,196,98,123.47,164.81,220]
    for k,start in enumerate(np.arange(0,dur,0.5)):
        f=notes[k%len(notes)]
        sig=karplus(f,1.8,0.9972)*exp_env(int(1.8*SR),.001,1.2)
        add_event(out,start,sig,pan=(-.45 if k%2==0 else .45),gain=.55)
        if k%4==0:
            sig2=karplus(f*1.5,2.2,0.9975)*exp_env(int(2.2*SR),.001,1.6)
            add_event(out,start+.03,sig2,pan=.2,gain=.32)
    out[:,0]=room(out[:,0],.55); out[:,1]=room(out[:,1],.65)
    return out

# Organ carrier: sustained drawbar-like harmonics with slow chord changes.
def organ_asset(dur=16):
    n=int(dur*SR); t=np.arange(n)/SR; out=np.zeros((n,2)); chords=[[65.41,98,130.81],[73.42,110,146.83],[55,82.41,110],[65.41,98,146.83]]
    seg=dur/4
    for c,ch in enumerate(chords):
        mask=(t>=c*seg)&(t<(c+1)*seg); tt=t[mask]-c*seg
        env=np.minimum(1,tt/.12)*np.minimum(1,(seg-tt)/.18)
        y=np.zeros(len(tt))
        for f in ch:
            for h,a in [(1,1),(2,.72),(3,.35),(4,.22),(6,.13),(8,.08)]:
                y+=a*np.sin(2*np.pi*f*h*tt+rng.random()*2*np.pi)
        y/=len(ch)*2.2
        trem=.93+.07*np.sin(2*np.pi*5.3*tt)
        out[mask,0]+=y*env*trem
        out[mask,1]+=np.roll(y,int(.004*SR))*env*(.93+.07*np.sin(2*np.pi*5.7*tt+1))
    return out

def old_radio(dur=16):
    n=int(dur*SR); out=np.zeros((n,2)); hiss=filt(rng.normal(0,1,n),lo=900,hi=7500,order=2)*.13
    hum=.025*np.sin(2*np.pi*50*np.arange(n)/SR)+.012*np.sin(2*np.pi*100*np.arange(n)/SR)
    mono=hiss+hum
    # crackle impulses
    for s in rng.uniform(0,dur,150):
        m=int(rng.uniform(.002,.025)*SR); sig=rng.normal(0,1,m)*np.exp(-np.arange(m)/(SR*rng.uniform(.002,.012)))
        i=int(s*SR); mono[i:min(n,i+m)]+=sig[:max(0,min(n-i,m))]*rng.uniform(.08,.35)
    out[:,0]=mono; out[:,1]=np.roll(mono,11)*.96
    return out

def rain_thunder(dur=24):
    n=int(dur*SR); t=np.arange(n)/SR; out=np.zeros((n,2))
    rain=0.18*filt(rng.normal(0,1,n),lo=450,hi=13500,order=2)+0.06*filt(rng.normal(0,1,n),lo=100,hi=1500,order=2)
    out[:,0]+=rain; out[:,1]+=np.roll(rain,137)*.95 + .03*filt(rng.normal(0,1,n),lo=800,hi=10000,order=2)
    for s in [4.5,12.2,19.0]:
        m=int(4*SR); tt=np.arange(m)/SR
        low=filt(rng.normal(0,1,m),hi=180,order=3)*np.exp(-tt/1.45)
        rum=.55*np.sin(2*np.pi*(42-8*tt)*tt)*np.exp(-tt/1.7)+low*.8
        add_event(out,s,rum,pan=rng.uniform(-.4,.4),gain=.65)
    return out

def jungle(dur=24):
    n=int(dur*SR); out=np.zeros((n,2)); wind=filt(pink(n),hi=1000,order=2)*.07
    insects=filt(rng.normal(0,1,n),lo=4000,hi=12000,order=2)*(.025*(.5+.5*np.sin(2*np.pi*.09*np.arange(n)/SR)))
    out[:,0]=wind+insects; out[:,1]=np.roll(wind,300)*.9+np.roll(insects,71)
    # birds: descending/ascending chirps
    for s in rng.uniform(.5,dur-.5,32):
        d=rng.uniform(.08,.35); m=int(d*SR); tt=np.arange(m)/SR
        f0=rng.uniform(1300,4300); f1=f0*rng.uniform(.65,1.55); phase=2*np.pi*(f0*tt+(f1-f0)/(2*d)*tt**2)
        sig=np.sin(phase)+.32*np.sin(2*phase)
        sig*=np.sin(np.pi*np.arange(m)/m)**1.7
        add_event(out,s,sig,pan=rng.uniform(-1,1),gain=rng.uniform(.04,.12))
    # frog/cicada pulses
    for s in rng.uniform(0,dur,15):
        m=int(.6*SR); tt=np.arange(m)/SR
        sig=np.sin(2*np.pi*(210+35*np.sin(2*np.pi*7*tt))*tt)*np.exp(-tt*4)*(np.sin(2*np.pi*9*tt)>0)
        add_event(out,s,sig,pan=rng.uniform(-.8,.8),gain=.05)
    return out

def crowd(dur=24):
    n=int(dur*SR); out=np.zeros((n,2))
    # Many independent band-limited pseudo-voices with syllabic envelopes.
    for v in range(38):
        base=filt(rng.normal(0,1,n),lo=rng.uniform(120,260),hi=rng.uniform(1200,3400),order=2)
        rate=rng.uniform(2.0,5.2); phase=rng.random()*2*np.pi
        env=np.maximum(0,np.sin(2*np.pi*rate*np.arange(n)/SR+phase))**rng.uniform(2,5)
        env*=.35+.65*filt(rng.random(n),hi=5,order=2)
        sig=base*env*.012
        pan=rng.uniform(-1,1); out[:,0]+=sig*math.sqrt((1-pan)*.5); out[:,1]+=np.roll(sig,rng.integers(0,120))*math.sqrt((1+pan)*.5)
    roomtone=filt(pink(n),lo=90,hi=5000,order=2)*.035
    out[:,0]+=roomtone; out[:,1]+=np.roll(roomtone,201)
    out[:,0]=room(out[:,0],.75); out[:,1]=room(out[:,1],.86)
    return out

def slot_machines(dur=20):
    n=int(dur*SR); out=np.zeros((n,2)); out += stereo(filt(rng.normal(0,1,n),lo=200,hi=6000,order=2)*.015)
    for s in rng.uniform(.2,dur-.2,85):
        d=rng.uniform(.06,.4); f=rng.choice([660,880,990,1175,1320,1760,2093]); m=int(d*SR); tt=np.arange(m)/SR
        sig=(np.sin(2*np.pi*f*tt)+.45*np.sin(2*np.pi*f*1.5*tt)+.2*np.sin(2*np.pi*f*2.02*tt))*np.exp(-tt/rng.uniform(.06,.22))
        add_event(out,s,sig,pan=rng.uniform(-1,1),gain=rng.uniform(.025,.10))
    for s in rng.uniform(0,dur,18):
        m=int(.08*SR); sig=filt(rng.normal(0,1,m),lo=1600,hi=9000,order=2)*np.exp(-np.arange(m)/(SR*.018))
        add_event(out,s,sig,pan=rng.uniform(-1,1),gain=.08)
    return out

def traffic(dur=24):
    n=int(dur*SR); t=np.arange(n)/SR; out=np.zeros((n,2)); base=filt(pink(n),lo=35,hi=1600,order=2)*.10
    out[:,0]=base; out[:,1]=np.roll(base,400)*.92
    for s in np.arange(1,dur-2,2.4):
        m=int(3*SR); tt=np.arange(m)/SR; center=1.5
        env=np.exp(-((tt-center)/.65)**2); freq=rng.uniform(55,110)
        engine=(np.sin(2*np.pi*freq*tt)+.35*np.sin(2*np.pi*freq*2.02*tt))*env
        hiss=filt(rng.normal(0,1,m),lo=300,hi=4500,order=2)*env*.25
        pan=np.linspace(-1,1,m) if int(s)%2 else np.linspace(1,-1,m)
        i=int(s*SR); mm=min(m,n-i)
        out[i:i+mm,0]+=(engine[:mm]*.06+hiss[:mm]*.06)*np.sqrt((1-pan[:mm])*.5)
        out[i:i+mm,1]+=(engine[:mm]*.06+hiss[:mm]*.06)*np.sqrt((1+pan[:mm])*.5)
    for s in [6.2,15.6]:
        d=.55; m=int(d*SR); tt=np.arange(m)/SR; sig=(np.sin(2*np.pi*430*tt)+.7*np.sin(2*np.pi*520*tt))*exp_env(m,.01,.28)
        add_event(out,s,sig,pan=rng.uniform(-.7,.7),gain=.10)
    return out

def crickets(dur=20):
    n=int(dur*SR); out=np.zeros((n,2)); bg=filt(rng.normal(0,1,n),lo=2500,hi=9500,order=2)*.015
    out[:,0]=bg; out[:,1]=np.roll(bg,97)
    for voice in range(10):
        f=rng.uniform(3500,6900); rate=rng.uniform(2.8,5.8); phase=rng.random()
        t=np.arange(n)/SR; gate=(np.mod(t*rate+phase,1)<rng.uniform(.18,.42)).astype(float)
        sig=np.sin(2*np.pi*f*t+2*np.sin(2*np.pi*rate*t))*gate*.018
        pan=rng.uniform(-1,1); out[:,0]+=sig*math.sqrt((1-pan)*.5); out[:,1]+=sig*math.sqrt((1+pan)*.5)
    return out

def bells(dur=18):
    n=int(dur*SR); out=np.zeros((n,2))
    for s in rng.uniform(0,dur,90):
        d=rng.uniform(.18,.8); m=int(d*SR); tt=np.arange(m)/SR; f=rng.uniform(1100,3900)
        sig=sum(a*np.sin(2*np.pi*f*r*tt) for r,a in [(1,1),(1.41,.55),(2.03,.35),(2.71,.22)])*np.exp(-tt/rng.uniform(.08,.35))
        add_event(out,s,sig,pan=rng.uniform(-1,1),gain=rng.uniform(.025,.08))
    return out

def applause(dur=18):
    n=int(dur*SR); out=np.zeros((n,2)); density=np.linspace(.35,1,n)
    # thousands of short, band-limited clap transients
    for s in rng.uniform(0,dur,1250):
        m=int(rng.uniform(.012,.055)*SR); tt=np.arange(m)/SR
        sig=filt(rng.normal(0,1,m),lo=500,hi=7000,order=2)*np.exp(-tt/rng.uniform(.006,.02))
        gain=rng.uniform(.008,.025)*(0.55+0.45*s/dur)
        add_event(out,s,sig,pan=rng.uniform(-1,1),gain=gain)
    out[:,0]=room(out[:,0],.65); out[:,1]=room(out[:,1],.78)
    return out

assets=[
 ('choir_bed.mp3',choir_asset(),'Sonarpad choir vowel bed','128k'),
 ('guitar_carrier.mp3',guitar_asset(),'Sonarpad guitar vocoder carrier','128k'),
 ('organ_carrier.mp3',organ_asset(),'Sonarpad organ vocoder carrier','128k'),
 ('old_radio_static.mp3',old_radio(),'Sonarpad old radio static','96k'),
 ('rain_thunder.mp3',rain_thunder(),'Sonarpad rain and thunder ambience','96k'),
 ('jungle_ambience.mp3',jungle(),'Sonarpad jungle ambience','96k'),
 ('crowd_ambience.mp3',crowd(),'Sonarpad crowd ambience','96k'),
 ('slot_machines.mp3',slot_machines(),'Sonarpad slot machines ambience','96k'),
 ('traffic_ambience.mp3',traffic(),'Sonarpad traffic ambience','96k'),
 ('crickets.mp3',crickets(),'Sonarpad crickets ambience','96k'),
 ('sleigh_bells.mp3',bells(),'Sonarpad sleigh bells ambience','96k'),
 ('applause.mp3',applause(),'Sonarpad applause ambience','96k'),
]
for name,data,title,br in assets: write_mp3(name,data,title,br)
