// Quick script to generate a test vector for "abc" message
// Run with: cargo run --example generate_test_vector

use ed25519_dalek::{Keypair, Signer, Verifier};

fn main() {
    use rand::rngs::OsRng;
    
    // Generate a keypair
    let mut csprng = OsRng{};
    let keypair: Keypair = Keypair::generate(&mut csprng);
    
    // Sign "abc"
    let message = b"abc";
    let signature = keypair.sign(message);
    
    println!("Public key: {:?}", keypair.public.as_bytes());
    println!("Signature: {:?}", signature.to_bytes());
    println!("Message: {:?}", message);
}



