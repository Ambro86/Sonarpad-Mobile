"""Generate a synthetic HLS fixture and serve it with redirects, cookies and headers."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1] / 'build' / 'rai-android-audit' / 'fixture'
stream = root / 'stream'
stream.mkdir(parents=True, exist_ok=True)
for name, source, codec in [
    ('video', 'testsrc=size=160x90:rate=15', ['-an', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-g', '30']),
    ('ita', 'sine=frequency=440:sample_rate=44100', ['-vn', '-c:a', 'aac']),
    ('ad', 'sine=frequency=880:sample_rate=44100', ['-vn', '-c:a', 'aac']),
]:
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 'lavfi', '-i', source,
        '-t', '30', *codec, '-f', 'hls', '-hls_time', '2', '-hls_list_size', '0',
        '-hls_segment_filename', str(stream / (name+'%02d.ts')), str(stream / (name+'.m3u8'))], check=True)
(stream / 'master.m3u8').write_text('#EXTM3U\n#EXT-X-VERSION:3\n'
    '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Italiano",LANGUAGE="ita",DEFAULT=YES,AUTOSELECT=YES,URI="ita.m3u8"\n'
    '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Audiodescrizione",LANGUAGE="des",DEFAULT=NO,AUTOSELECT=YES,CHARACTERISTICS="public.accessibility.describes-video",URI="ad.m3u8"\n'
    '#EXT-X-STREAM-INF:BANDWIDTH=300000,RESOLUTION=160x90,CODECS="avc1.64000b,mp4a.40.2",AUDIO="audio"\nvideo.m3u8\n', encoding='utf-8')
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(root), **kwargs)
    def do_GET(self):
        if self.headers.get('X-Sonarpad-Test') != 'rai-fixture':
            self.send_error(403); return
        if self.path == '/master.m3u8':
            self.send_response(302)
            self.send_header('Location', '/stream/master.m3u8')
            self.send_header('Set-Cookie', 'rai_session=fixture; Path=/stream')
            self.end_headers(); return
        if 'rai_session=fixture' not in self.headers.get('Cookie', ''):
            self.send_error(403); return
        super().do_GET()
print('Synthetic HLS fixture ready on port 18765', flush=True)
ThreadingHTTPServer(('0.0.0.0', 18765), Handler).serve_forever()
