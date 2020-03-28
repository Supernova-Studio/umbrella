class Header {

  final String glob;
  final bool ignoreGeneratedFiles;
  final bool ignorePrivateFiles;

  const Header({
    this.glob = "**",
    this.ignoreGeneratedFiles = true,
    this.ignorePrivateFiles = false
  });

  @override
  String toString() {
    return 'Header{glob: $glob, ignoreGeneratedFiles: $ignoreGeneratedFiles, ignorePrivateFiles: $ignorePrivateFiles}';
  }
}
