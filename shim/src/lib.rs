//! Nito Shim - C-ABI bridge between Nim and Solana Rust SDK
//!
//! This crate exposes Solana types and functions as extern "C" for FFI
//! All functions must be panic-safe (catch_unwind) to prevent unwinding across FFI boundary

use std::panic;
use std::ffi::{c_char, c_int};
use std::slice;

/// Solana Pubkey (32 bytes)
#[repr(C)]
pub struct Pubkey {
    pub bytes: [u8; 32],
}

/// Solana Hash (32 bytes, SHA-256)
#[repr(C)]
pub struct Hash {
    pub bytes: [u8; 32],
}

/// Error codes returned to Nim
#[repr(C)]
pub enum NitoError {
    Success = 0,
    InvalidInput = 1,
    VerificationFailed = 2,
    PanicCaught = 3,
}

/// Ed25519 signature verification result
#[repr(C)]
pub struct VerifyResult {
    pub success: c_int,  // 1 for success, 0 for failure
    pub error_code: NitoError,
}

/// Sign a message with Ed25519
///
/// # Safety
/// This function is unsafe because it operates on raw pointers.
/// The caller must ensure:
/// - msg_ptr points to a valid buffer of msg_len bytes
/// - secret_key_ptr points to a valid 32-byte secret key
/// - out_sig_ptr points to a valid 64-byte buffer for the signature
#[no_mangle]
pub extern "C" fn sign_ed25519(
    msg_ptr: *const u8,
    msg_len: usize,
    secret_key_ptr: *const u8,
    out_sig_ptr: *mut u8,
) -> VerifyResult {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        // Safety: We trust the caller to provide valid pointers
        if (msg_len > 0 && msg_ptr.is_null()) || secret_key_ptr.is_null() || out_sig_ptr.is_null() {
            return VerifyResult {
                success: 0,
                error_code: NitoError::InvalidInput,
            };
        }

        // Handle empty message case
        let msg = if msg_len == 0 {
            &[]
        } else {
            unsafe { slice::from_raw_parts(msg_ptr, msg_len) }
        };
        let secret_key_bytes = unsafe { slice::from_raw_parts(secret_key_ptr, 32) };

        // Use ed25519-dalek v1.0 for signing
        // In v1.0, it's called Keypair, not SigningKey (SigningKey is v2.0+)
        use ed25519_dalek::{Signer, Keypair, SecretKey, PublicKey};
        
        // In ed25519-dalek v1.0, we need to create a SecretKey first, then Keypair
        // SecretKey::from_bytes expects a 32-byte array and returns a Result
        let secret_key_array: [u8; 32] = match secret_key_bytes.try_into() {
            Ok(arr) => arr,
            Err(_) => {
                return VerifyResult {
                    success: 0,
                    error_code: NitoError::InvalidInput,
                };
            }
        };
        
        let secret_key = match SecretKey::from_bytes(&secret_key_array) {
            Ok(key) => key,
            Err(_) => {
                return VerifyResult {
                    success: 0,
                    error_code: NitoError::InvalidInput,
                };
            }
        };
        
        // Create public key from secret key, then create keypair
        let public_key = PublicKey::from(&secret_key);
        let keypair = Keypair { secret: secret_key, public: public_key };

        let signature = keypair.sign(msg);
        let sig_bytes = signature.to_bytes();

        // Write signature to output buffer
        unsafe {
            let out_slice = slice::from_raw_parts_mut(out_sig_ptr, 64);
            out_slice.copy_from_slice(&sig_bytes);
        }

        VerifyResult {
            success: 1,
            error_code: NitoError::Success,
        }
    }));

    match result {
        Ok(sign_result) => sign_result,
        Err(_) => VerifyResult {
            success: 0,
            error_code: NitoError::PanicCaught,
        },
    }
}

/// Verify an Ed25519 signature
///
/// # Safety
/// This function is unsafe because it operates on raw pointers.
/// The caller must ensure:
/// - msg_ptr points to a valid buffer of msg_len bytes
/// - sig_ptr points to a valid 64-byte signature
/// - pubkey_ptr points to a valid 32-byte public key
#[no_mangle]
pub extern "C" fn verify_ed25519(
    msg_ptr: *const u8,
    msg_len: usize,
    sig_ptr: *const u8,
    pubkey_ptr: *const u8,
) -> VerifyResult {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        // Safety: We trust the caller to provide valid pointers
        // In production, we'd add bounds checking
        // Note: msg_ptr can be null if msg_len is 0 (empty message)
        if (msg_len > 0 && msg_ptr.is_null()) || sig_ptr.is_null() || pubkey_ptr.is_null() {
            return VerifyResult {
                success: 0,
                error_code: NitoError::InvalidInput,
            };
        }

        // Handle empty message case - msg_ptr can be null if msg_len is 0
        let msg = if msg_len == 0 {
            &[]
        } else {
            unsafe { slice::from_raw_parts(msg_ptr, msg_len) }
        };
        let sig = unsafe { slice::from_raw_parts(sig_ptr, 64) };
        let pubkey = unsafe { slice::from_raw_parts(pubkey_ptr, 32) };

        // Use ed25519-dalek v1.0 for verification
        use ed25519_dalek::{PublicKey, Signature, Verifier};

        let public_key = match PublicKey::from_bytes(pubkey) {
            Ok(key) => key,
            Err(_) => {
                return VerifyResult {
                    success: 0,
                    error_code: NitoError::InvalidInput,
                };
            }
        };

        let signature = match Signature::from_bytes(sig) {
            Ok(sig) => sig,
            Err(_) => {
                return VerifyResult {
                    success: 0,
                    error_code: NitoError::InvalidInput,
                };
            }
        };

        match public_key.verify(msg, &signature) {
            Ok(_) => VerifyResult {
                success: 1,
                error_code: NitoError::Success,
            },
            Err(_) => VerifyResult {
                success: 0,
                error_code: NitoError::VerificationFailed,
            },
        }
    }));

    match result {
        Ok(verify_result) => verify_result,
        Err(_) => VerifyResult {
            success: 0,
            error_code: NitoError::PanicCaught,
        },
    }
}

/// Get the version string of the shim
#[no_mangle]
pub extern "C" fn nito_shim_version() -> *const c_char {
    b"nito_shim 0.1.0\0".as_ptr() as *const c_char
}

/// Create a zero-initialized Pubkey
#[no_mangle]
pub extern "C" fn pubkey_zero() -> Pubkey {
    Pubkey { bytes: [0u8; 32] }
}

/// Create a Pubkey from bytes
///
/// # Safety
/// pubkey_bytes must point to a valid 32-byte array
#[no_mangle]
pub extern "C" fn pubkey_from_bytes(pubkey_bytes: *const u8) -> Pubkey {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        if pubkey_bytes.is_null() {
            return Pubkey { bytes: [0u8; 32] };
        }
        let bytes = unsafe { slice::from_raw_parts(pubkey_bytes, 32) };
        let mut pubkey = Pubkey { bytes: [0u8; 32] };
        pubkey.bytes.copy_from_slice(bytes);
        pubkey
    }));
    result.unwrap_or_else(|_| Pubkey { bytes: [0u8; 32] })
}

/// Compare two Pubkeys for equality
#[no_mangle]
pub extern "C" fn pubkey_eq(a: *const Pubkey, b: *const Pubkey) -> c_int {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        if a.is_null() || b.is_null() {
            return 0;
        }
        let a_bytes = unsafe { &(*a).bytes };
        let b_bytes = unsafe { &(*b).bytes };
        if a_bytes == b_bytes { 1 } else { 0 }
    }));
    result.unwrap_or(0)
}

/// Create a zero-initialized Hash
#[no_mangle]
pub extern "C" fn hash_zero() -> Hash {
    Hash { bytes: [0u8; 32] }
}

/// Compute SHA-256 hash of data
///
/// # Safety
/// data_ptr must point to a valid buffer of data_len bytes
/// out_hash must point to a valid Hash struct
#[no_mangle]
pub extern "C" fn hash_sha256(data_ptr: *const u8, data_len: usize, out_hash: *mut Hash) -> c_int {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        if data_ptr.is_null() || out_hash.is_null() {
            return 0;
        }
        let data = unsafe { slice::from_raw_parts(data_ptr, data_len) };
        use sha2::{Sha256, Digest};
        let mut hasher = Sha256::new();
        hasher.update(data);
        let hash_bytes = hasher.finalize();
        
        unsafe {
            (*out_hash).bytes.copy_from_slice(&hash_bytes);
        }
        1
    }));
    result.unwrap_or(0)
}

/// Account state information
#[repr(C)]
pub struct AccountState {
    pub exists: c_int,      // 1 if account exists, 0 otherwise
    pub lamports: u64,      // Account balance in lamports
    pub owner: Pubkey,      // Account owner (program ID)
    pub executable: c_int,  // 1 if executable, 0 otherwise
    pub rent_epoch: u64,    // Rent epoch
}

/// Get account balance from ledger state
///
/// # Safety
/// pubkey_ptr must point to a valid 32-byte Pubkey
/// 
/// Note: This is a placeholder implementation. In production, this would
/// query the actual ledger state via Solana SDK. For now, returns 0.
#[no_mangle]
pub extern "C" fn get_account_balance(pubkey_ptr: *const Pubkey) -> u64 {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        if pubkey_ptr.is_null() {
            return 0u64;
        }
        
        // TODO: In production, query actual ledger state
        // For now, return 0 (account not found or zero balance)
        // This will be replaced with real ledger access in Phase 4
        0u64
    }));
    result.unwrap_or(0u64)
}

/// Check if an account exists in ledger state
///
/// # Safety
/// pubkey_ptr must point to a valid 32-byte Pubkey
///
/// Note: This is a placeholder implementation. In production, this would
/// query the actual ledger state via Solana SDK. For now, returns 0 (does not exist).
#[no_mangle]
pub extern "C" fn account_exists(pubkey_ptr: *const Pubkey) -> c_int {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        if pubkey_ptr.is_null() {
            return 0;
        }
        
        // TODO: In production, query actual ledger state
        // For now, return 0 (account does not exist)
        // This will be replaced with real ledger access in Phase 4
        0
    }));
    result.unwrap_or(0)
}

/// Get full account state from ledger
///
/// # Safety
/// pubkey_ptr must point to a valid 32-byte Pubkey
/// out_state must point to a valid AccountState struct
///
/// Note: This is a placeholder implementation. In production, this would
/// query the actual ledger state via Solana SDK. For now, returns 0 (not found).
#[no_mangle]
pub extern "C" fn get_account_state(pubkey_ptr: *const Pubkey, out_state: *mut AccountState) -> c_int {
    let result = panic::catch_unwind(panic::AssertUnwindSafe(|| {
        if pubkey_ptr.is_null() || out_state.is_null() {
            return 0;
        }
        
        // TODO: In production, query actual ledger state
        // For now, set exists to 0 (account not found)
        unsafe {
            (*out_state).exists = 0;
            (*out_state).lamports = 0;
            (*out_state).owner = Pubkey { bytes: [0u8; 32] };
            (*out_state).executable = 0;
            (*out_state).rent_epoch = 0;
        }
        
        0 // Account not found
    }));
    result.unwrap_or(0)
}

