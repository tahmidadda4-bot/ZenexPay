/// Converts low-level network/client errors into safe, user-friendly text.
/// Never exposes SocketException, PostgreSQL/PostgREST, host lookup, or URL details.
String friendlyError(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  final raw = error.toString().toLowerCase();

  const networkMarkers = [
    'socketexception',
    'clientexception',
    'failed host lookup',
    'no address associated with hostname',
    'network is unreachable',
    'connection refused',
    'connection reset',
    'connection closed',
    'connection timed out',
    'timed out',
    'failed to connect',
    'network request failed',
    'could not resolve host',
    'temporary failure in name resolution',
    'dns',
    'broken pipe',
  ];

  if (networkMarkers.any(raw.contains)) {
    return 'Please connect to internet.\nInternet not connected.';
  }

  // Auth libraries can return a generic network message without exposing
  // the underlying SocketException.
  if (raw.contains('network') || raw.contains('internet') || raw.contains('offline')) {
    return 'Please connect to internet.\nInternet not connected.';
  }

  return fallback;
}
