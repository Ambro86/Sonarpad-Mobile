import 'dart:io';

void main() {
  File('.github/workflows/ios-build.yml').copySync('.github/workflows/ios-build.yml.bac');
}
