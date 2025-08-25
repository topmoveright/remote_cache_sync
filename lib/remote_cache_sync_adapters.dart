// Adapter barrel: import this when you need backend-specific remote stores.
// Keeping adapters out of the core entrypoint preserves WASM compatibility.

export 'sync/remote/supabase_remote_store.dart';
export 'sync/remote/appwrite_remote_store.dart';
export 'sync/remote/pocketbase_remote_store.dart';
