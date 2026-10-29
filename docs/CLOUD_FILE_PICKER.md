# File cloud: progress and cancellation (Sonarpad Mobile 0.5.1)

The common file-selection helper is `lib/services/cloud_file_picker_service.dart`.
It is used by every current screen that opens files with `FilePicker.pickFiles`,
including audiodescriptions, project edits, Documents, media conversion/cutter/join,
news and podcast OPML import. Save and directory pickers are unchanged.

On Android, ACTION_OPEN_DOCUMENT returns a provider content URI and the native
bridge streams it into Sonarpad's cache while emitting the actual byte count.
On iOS, UIDocumentPicker returns a security-scoped URL and NSFileCoordinator
provides the coordinated read, followed by the same byte-counted copy.

Files are accepted by Dart only after the copy has finished. Cancellation
closes the active read, removes incomplete files, and returns null. Multiple
files are copied sequentially. The UI shows a determinate percentage only when
the provider supplies a reliable size. Some providers resolve/download content
inside the system picker or file-coordination step without providing byte
progress; during that stage the dialog is indeterminate. Never display fake
percentages. The operating system can clear the cache at any time.

This code needs device testing with Apple Files/iCloud, Google Drive, Dropbox,
Android DocumentsUI, and VoiceOver/TalkBack. Full native compilation was not
available in the coding environment.
