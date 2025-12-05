//! Nito Shim - C-ABI bridge between Nim and Solana Rust SDK
//!
//! This crate exposes Solana types and functions as extern "C" for FFI
//! All functions must be panic-safe (catch_unwind) to prevent unwinding across FFI boundary

use std::panic;
use std::ffi::{c_char, c_int, c_void};
use std::ptr;
use std::slice;

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
        if msg_ptr.is_null() || sig_ptr.is_null() || pubkey_ptr.is_null() {
            return VerifyResult {
                success: 0,
                error_code: NitoError::InvalidInput,
            };
        }

        let msg = unsafe { slice::from_raw_parts(msg_ptr, msg_len) };
        let sig = unsafe { slice::from_raw_parts(sig_ptr, 64) };
        let pubkey = unsafe { slice::from_raw_parts(pubkey_ptr, 32) };

        // Use ed25519-dalek for verification
        use ed25519_dalek::{Signature, Verifier, VerifyingKey};

        let verifying_key = match VerifyingKey::from_bytes(pubkey.try_into().unwrap()) {
            Ok(key) => key,
            Err(_) => {
                return VerifyResult {
                    success: 0,
                    error_code: NitoError::InvalidInput,
                };
            }
        };

        let signature = match Signature::from_bytes(sig.try_into().unwrap()) {
            Ok(sig) => sig,
            Err(_) => {
                return VerifyResult {
                    success: 0,
                    error_code: NitoError::InvalidInput,
                };
            }
        };

        match verifying_key.verify(msg, &signature) {
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

