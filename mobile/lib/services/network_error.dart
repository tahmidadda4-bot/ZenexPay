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

  // Referral RPC errors should be understandable to the user instead of
  // collapsing into the generic fallback message.
  if (raw.contains('invalid referral code')) {
    return 'Invalid referral code. Please check the code and try again.';
  }
  if (raw.contains('own referral code')) {
    return 'You cannot use your own referral code.';
  }
  if (raw.contains('already been applied')) {
    return 'A referral code has already been applied to this account.';
  }
  if (raw.contains('referral code cannot be empty')) {
    return 'Please enter a referral code.';
  }
  if (raw.contains('not authenticated')) {
    return 'Your session has expired. Please log in again.';
  }
  if (raw.contains('daily check-in already claimed today')) {
    return 'Daily check-in is already claimed today.';
  }
  if (raw.contains('wallet not found')) {
    return 'Your wallet is not ready yet. Please try again.';
  }
  if (raw.contains('promotion already claimed today')) {
    return 'This reward has already been claimed today.';
  }
  if (raw.contains('promotion is not active')) {
    return 'This reward is no longer active.';
  }
  if (raw.contains('this promotion has no cash reward')) {
    return 'This item is view-only and has no cash reward.';
  }
  if (raw.contains('promotion is informational')) {
    return 'This announcement is view-only.';
  }

  if (raw.contains('task is no longer available')) {
    return 'This task is no longer available.';
  }
  if (raw.contains('already pending review')) {
    return 'This task is already pending review. Please wait for the current review to finish.';
  }
  if (raw.contains('already been completed and paid')) {
    return 'You have already completed this task and received the reward.';
  }
  if (raw.contains('screenshot was requested')) {
    return 'A screenshot was requested for this task. Please upload it from My Submissions.';
  }
  if (raw.contains('screenshot is already under review')) {
    return 'Your screenshot is already under review. Please wait for the reviewer.';
  }
  if (raw.contains('task system is temporarily disabled')) {
    return 'Task submissions are temporarily disabled.';
  }
  if (raw.contains('account is blocked')) {
    return 'Your account is currently blocked.';
  }

  // Auth libraries can return a generic network message without exposing
  // the underlying SocketException.
  if (raw.contains('network') || raw.contains('internet') || raw.contains('offline')) {
    return 'Please connect to internet.\nInternet not connected.';
  }

  return fallback;
}
