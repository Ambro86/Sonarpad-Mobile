"""Reject iOS builds missing the scene lifecycle required by the iOS 27 SDK."""
from pathlib import Path
import plistlib
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def validate(data):
    manifest = data.get('UIApplicationSceneManifest', {})
    if manifest.get('UIApplicationSupportsMultipleScenes') is not False:
        raise ValueError('Missing single-scene UIApplicationSceneManifest')
    scenes = manifest.get('UISceneConfigurations', {}).get(
        'UIWindowSceneSessionRoleApplication', [])
    if len(scenes) != 1:
        raise ValueError('Expected one application scene')
    scene = scenes[0]
    if scene.get('UISceneClassName') != 'UIWindowScene':
        raise ValueError('Missing UIWindowScene class')
    if not scene.get('UISceneDelegateClassName', '').endswith('.SceneDelegate'):
        raise ValueError('Sonarpad SceneDelegate is not connected')
    if scene.get('UISceneStoryboardFile') != 'Main':
        raise ValueError('Scene must load the existing Main storyboard')
    if not data.get('UILaunchStoryboardName'):
        raise ValueError('Launch storyboard is missing')


def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'ios/Runner/Info.plist'
    if path.suffix == '.ipa':
        with zipfile.ZipFile(path) as archive:
            names = [n for n in archive.namelist()
                     if n.startswith('Payload/') and n.endswith('.app/Info.plist')
                     and len(n.split('/')) == 3]
            if len(names) != 1:
                raise ValueError('Expected one main application in IPA')
            data = plistlib.loads(archive.read(names[0]))
        if data.get('MinimumOSVersion') != '15.5':
            raise ValueError('IPA must retain the iOS 15.5 deployment target')
    else:
        data = plistlib.loads(path.read_bytes())
    validate(data)
    print('iOS scene lifecycle configuration OK')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        print(f'iOS launch configuration error: {error}', file=sys.stderr)
        sys.exit(1)
