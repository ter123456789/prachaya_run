/// Port: opens a page in the system browser (linking a watch account).
abstract interface class ExternalBrowser {
  Future<bool> open(Uri url);
}
