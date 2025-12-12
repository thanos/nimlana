## Tests for bundle simulation module

import unittest
import std/strutils
import std/options
import ../src/nimlana/types
import ../src/nimlana/bundle
import ../src/nimlana/simulation
import ../src/nimlana/borsh
import ../src/nimlana/buffer

# Use types.zeroPubkey explicitly to avoid ambiguity with ffi.zeroPubkey
# (bundle.nim imports ffi which brings ffi.zeroPubkey into scope)

suite "Bundle Simulation":
  test "Simulate empty bundle should fail":
    var accountBalances: seq[AccountBalance] = @[]
    var parsedBundle = ParsedBundle(
      transactions: @[],
      tipAccount: types.zeroPubkey(),
      tipAmount: 0'u64,
    )
    
    let result = simulateBundle(parsedBundle, accountBalances)
    check result.success == false
    check result.errorMessage.contains("no transactions")
  
  test "Simulate transaction with no signatures should fail":
    var accountBalances: seq[AccountBalance] = @[]
    var tx = ParsedTransaction(
      rawData: @[],
      signatures: @[],
      message: @[0x01.byte],
      tipAccount: none(Pubkey),
      tipAmount: 0'u64,
    )
    
    let (success, errorMsg) = simulateTransaction(tx, accountBalances)
    check success == false
    check errorMsg.contains("no signatures")
  
  test "Simulate transaction with invalid signature should fail":
    var accountBalances: seq[AccountBalance] = @[]
    var zeroSig: Signature
    var tx = ParsedTransaction(
      rawData: @[],
      signatures: @[zeroSig],
      message: @[0x01.byte],
      tipAccount: none(Pubkey),
      tipAmount: 0'u64,
    )
    
    let (success, errorMsg) = simulateTransaction(tx, accountBalances)
    check success == false
    check errorMsg.contains("Invalid signature")
  
  test "Simulate transaction with fee payer account":
    var feePayer: Pubkey = types.zeroPubkey()
    feePayer[0] = 0x01
    
    var accountBalances: seq[AccountBalance] = @[
      AccountBalance(
        pubkey: feePayer,
        lamports: 100000'u64,
        exists: true,
      ),
    ]
    
    # Create a minimal valid transaction
    var txData: seq[byte] = @[]
    txData.add(1.byte) # 1 signature
    for i in 0 ..< 64:
      txData.add((i mod 256).byte) # Non-zero signature
    # Minimal message: header (3 bytes) + 1 account (32 bytes) + blockhash (32 bytes) + 0 instructions
    txData.add(1.byte) # numRequiredSignatures
    txData.add(0.byte) # numReadonlySignedAccounts
    txData.add(0.byte) # numReadonlyUnsignedAccounts
    for i in 0 ..< 32:
      txData.add(feePayer[i]) # Account key
    for i in 0 ..< 32:
      txData.add(0.byte) # Blockhash
    txData.add(0.byte) # Instruction count (compact-u16, single byte)
    txData.add(0.byte)
    
    let parsedTx = parseTransaction(txData)
    let (success, errorMsg) = simulateTransaction(parsedTx, accountBalances)
    check success == true
    check errorMsg == ""
  
  test "Simulate transaction with insufficient balance should fail":
    var feePayer: Pubkey = types.zeroPubkey()
    feePayer[0] = 0x01
    
    var accountBalances: seq[AccountBalance] = @[
      AccountBalance(
        pubkey: feePayer,
        lamports: 1000'u64, # Less than minimum fee
        exists: true,
      ),
    ]
    
    # Create a minimal valid transaction
    var txData: seq[byte] = @[]
    txData.add(1.byte) # 1 signature
    for i in 0 ..< 64:
      txData.add((i mod 256).byte) # Non-zero signature
    # Minimal message
    txData.add(1.byte) # numRequiredSignatures
    txData.add(0.byte) # numReadonlySignedAccounts
    txData.add(0.byte) # numReadonlyUnsignedAccounts
    for i in 0 ..< 32:
      txData.add(feePayer[i]) # Account key
    for i in 0 ..< 32:
      txData.add(0.byte) # Blockhash
    txData.add(0.byte) # Instruction count
    txData.add(0.byte)
    
    let parsedTx = parseTransaction(txData)
    let (success, errorMsg) = simulateTransaction(parsedTx, accountBalances)
    check success == false
    check errorMsg.contains("Insufficient balance")
  
  test "Validate bundle for submission":
    var feePayer: Pubkey = types.zeroPubkey()
    feePayer[0] = 0x01
    
    var tipAccount: Pubkey = types.zeroPubkey()
    tipAccount[0] = 0x02
    
    var accountBalances: seq[AccountBalance] = @[
      AccountBalance(
        pubkey: feePayer,
        lamports: 100000'u64,
        exists: true,
      ),
      AccountBalance(
        pubkey: tipAccount,
        lamports: 50000'u64,
        exists: true,
      ),
    ]
    
    # Create a bundle with one transaction
    var txData: seq[byte] = @[]
    txData.add(1.byte) # 1 signature
    for i in 0 ..< 64:
      txData.add((i mod 256).byte) # Non-zero signature
    # Minimal message
    txData.add(1.byte) # numRequiredSignatures
    txData.add(0.byte) # numReadonlySignedAccounts
    txData.add(0.byte) # numReadonlyUnsignedAccounts
    for i in 0 ..< 32:
      txData.add(feePayer[i]) # Account key
    for i in 0 ..< 32:
      txData.add(0.byte) # Blockhash
    txData.add(0.byte) # Instruction count
    txData.add(0.byte)
    
    let parsedTx = parseTransaction(txData)
    var parsedBundle = ParsedBundle(
      transactions: @[parsedTx],
      tipAccount: tipAccount,
      tipAmount: 10000'u64,
    )
    
    let (isValid, errorMsg) = validateBundleForSubmission(parsedBundle, accountBalances)
    check isValid == true
    check errorMsg == ""
  
  test "Validate bundle with insufficient tip balance should fail":
    var feePayer: Pubkey = types.zeroPubkey()
    feePayer[0] = 0x01
    
    var tipAccount: Pubkey = types.zeroPubkey()
    tipAccount[0] = 0x02
    
    var accountBalances: seq[AccountBalance] = @[
      AccountBalance(
        pubkey: feePayer,
        lamports: 100000'u64,
        exists: true,
      ),
      AccountBalance(
        pubkey: tipAccount,
        lamports: 1000'u64, # Less than tip amount
        exists: true,
      ),
    ]
    
    # Create a bundle with one transaction
    var txData: seq[byte] = @[]
    txData.add(1.byte) # 1 signature
    for i in 0 ..< 64:
      txData.add((i mod 256).byte) # Non-zero signature
    # Minimal message
    txData.add(1.byte) # numRequiredSignatures
    txData.add(0.byte) # numReadonlySignedAccounts
    txData.add(0.byte) # numReadonlyUnsignedAccounts
    for i in 0 ..< 32:
      txData.add(feePayer[i]) # Account key
    for i in 0 ..< 32:
      txData.add(0.byte) # Blockhash
    txData.add(0.byte) # Instruction count
    txData.add(0.byte)
    
    let parsedTx = parseTransaction(txData)
    var parsedBundle = ParsedBundle(
      transactions: @[parsedTx],
      tipAccount: tipAccount,
      tipAmount: 10000'u64, # More than available balance
    )
    
    let (isValid, errorMsg) = validateBundleForSubmission(parsedBundle, accountBalances)
    check isValid == false
    check errorMsg.contains("Insufficient balance")

suite "Account Balance Lookup":
  test "Get account balance":
    var pubkey: Pubkey = types.zeroPubkey()
    pubkey[0] = 0xAA
    
    var accountBalances: seq[AccountBalance] = @[
      AccountBalance(
        pubkey: pubkey,
        lamports: 50000'u64,
        exists: true,
      ),
    ]
    
    let balance = getAccountBalance(pubkey, accountBalances)
    check balance.isSome()
    check balance.get().lamports == 50000'u64
    check balance.get().exists == true
  
  test "Get non-existent account balance":
    var pubkey: Pubkey = types.zeroPubkey()
    pubkey[0] = 0xAA
    
    var accountBalances: seq[AccountBalance] = @[]
    
    let balance = getAccountBalance(pubkey, accountBalances)
    check balance.isNone()

