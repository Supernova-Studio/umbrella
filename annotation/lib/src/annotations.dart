class Header {
  final List<String> include;
  final List<String> exclude;
  final bool ignoreGeneratedFiles;
  final bool ignorePrivateFiles;

  const Header(
      {this.include = const ["**"],
      this.exclude = const [],
      this.ignoreGeneratedFiles = true,
      this.ignorePrivateFiles = false});

  @override
  String toString() {
    return 'Header{include: $include, exclude: $exclude, '
        'ignoreGeneratedFiles: $ignoreGeneratedFiles, ignorePrivateFiles: $ignorePrivateFiles}';
  }
}
