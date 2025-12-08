## Integration tests for tip payment extraction
## Tests with real Solana transaction structures

import unittest
import ../src/nimlana/types
import ../src/nimlana/bundle
import ../src/nimlana/message_parser
import ../src/nimlana/borsh
import std/options

suite "Tip Payment Extraction Integration Tests":
  test "Parse transaction with message":
    # Create a minimal transaction with message
    var txData: seq[byte] = @[]
    txData.add(1.byte) # 1 signature
    
    # Add signature (64 bytes)
    for i in 0 ..< 64:
      txData.add(i.byte)
    
    # Add minimal message (header + accounts + blockhash + instructions)
    # Message header: 3 bytes
    txData.add(1.byte) # numRequiredSignatures
    txData.add(0.byte) # numReadonlySignedAccounts
    txData.add(0.byte) # numReadonlyUnsignedAccounts
    
    # Account keys (at least 1, 32 bytes each)
    for i in 0 ..< 32:
      txData.add(i.byte)
    
    # Recent blockhash (32 bytes)
    for i in 0 ..< 32:
      txData.add((i + 100).byte)
    
    # Instructions count (compact-u16): 0 instructions
    txData.add(0.byte)
    
    let parsed = parseTransaction(txData)
    check parsed.signatures.len == 1
    check parsed.message.len > 0
    
    # Extract tip payment (should return none if no tip instruction)
    let (tipAccount, tipAmount) = extractTipPayment(parsed)
    # For this minimal transaction, no tip should be found
    check tipAmount == 0

  test "Parse message structure":
    # Create a message with Compute Budget program
    var message: seq[byte] = @[]
    
    # Message header: 1 required signature, 0 readonly signed, 1 readonly unsigned (Compute Budget)
    message.add(1.byte) # numRequiredSignatures
    message.add(0.byte) # numReadonlySignedAccounts
    message.add(1.byte) # numReadonlyUnsignedAccounts (Compute Budget program is readonly unsigned)
    
    # Account keys (2 accounts: fee payer + Compute Budget program)
    # Account 0: Fee payer (32 bytes)
    for i in 0 ..< 32:
      message.add(i.byte)
    
    # Account 1: Compute Budget program (32 bytes)
    # ComputeBudget111111111111111111111111111111
    let computeBudgetId = [
      0x06.byte, 0x16, 0x8F, 0xDE, 0x38, 0x2E, 0x0F, 0xCD, 0x3C, 0x5E, 0x0C, 0x93,
      0xCA, 0x41, 0xE0, 0xFB, 0x83, 0x21, 0x0D, 0x52, 0xDF, 0x87, 0x5E, 0x81,
      0xE4, 0x6E, 0x6F, 0x6B, 0x7F, 0x7C, 0x6E, 0x6B,
    ]
    for b in computeBudgetId:
      message.add(b)
    
    # Recent blockhash (32 bytes)
    for i in 0 ..< 32:
      message.add((i + 200).byte)
    
    # Instructions count: 1 instruction (compact-u16: 1 = 0x01)
    message.add(1.byte) # compact-u16: 1 (single byte, < 128)
    
    # Instruction: Compute Budget priority fee
    message.add(1.byte) # programIdIndex (Compute Budget)
    message.add(1.byte) # account count: 1 (compact-u16)
    message.add(0.byte) # account index 0
    message.add(9.byte) # data length: 9 (1 byte discriminator + 8 bytes u64)
    message.add(3.byte) # discriminator (SetPriorityFee)
    # Tip amount: 1000 lamports (u64, little-endian)
    let tipBytes = borshSerializeU64(1000'u64)
    for b in tipBytes:
      message.add(b)
    
    # Parse the message
    let parsedMessage = parseMessage(message)
    check parsedMessage.accountKeys.len == 2
    check parsedMessage.instructions.len == 1
    
    # Check if Compute Budget program is detected
    let programId = parsedMessage.accountKeys[parsedMessage.instructions[0].programIdIndex.int]
    check isComputeBudgetProgram(programId)
    
    # Extract tip from instruction
    let (tipAccount, tipAmount) = extractTipFromInstruction(
      parsedMessage.instructions[0], parsedMessage.accountKeys
    )
    check tipAmount == 1000'u64

  test "Extract tip payment from full transaction":
    # Create a transaction with tip payment instruction
    var txData: seq[byte] = @[]
    txData.add(1.byte) # 1 signature
    
    # Signature (64 bytes)
    for i in 0 ..< 64:
      txData.add(i.byte)
    
    # Message with tip payment
    # Header: 1 required signature, 0 readonly signed, 1 readonly unsigned (Compute Budget)
    txData.add(1.byte) # numRequiredSignatures
    txData.add(0.byte) # numReadonlySignedAccounts
    txData.add(1.byte) # numReadonlyUnsignedAccounts
    
    # Account 0: Fee payer (required signature)
    for i in 0 ..< 32:
      txData.add(i.byte)
    
    # Account 1: Compute Budget program (readonly unsigned)
    let computeBudgetId = [
      0x06.byte, 0x16, 0x8F, 0xDE, 0x38, 0x2E, 0x0F, 0xCD, 0x3C, 0x5E, 0x0C, 0x93,
      0xCA, 0x41, 0xE0, 0xFB, 0x83, 0x21, 0x0D, 0x52, 0xDF, 0x87, 0x5E, 0x81,
      0xE4, 0x6E, 0x6F, 0x6B, 0x7F, 0x7C, 0x6E, 0x6B,
    ]
    for b in computeBudgetId:
      txData.add(b)
    
    # Blockhash
    for i in 0 ..< 32:
      txData.add((i + 100).byte)
    
    # Instructions: 1 (compact-u16)
    txData.add(1.byte)
    
    # Instruction
    txData.add(1.byte) # programIdIndex (Compute Budget is account index 1)
    txData.add(1.byte) # account count: 1 (compact-u16)
    txData.add(0.byte) # account index 0 (fee payer)
    txData.add(9.byte) # data length: 9 (compact-u16)
    txData.add(3.byte) # discriminator (SetPriorityFee)
    let tipBytes = borshSerializeU64(5000'u64)
    for b in tipBytes:
      txData.add(b)
    
    let parsed = parseTransaction(txData)
    let (tipAccount, tipAmount) = extractTipPayment(parsed)
    
    # Should extract tip amount
    check tipAmount == 5000'u64
    check tipAccount.isSome()

