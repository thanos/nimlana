## Comprehensive tests for errors.nim
## Tests all error types, error raising, and error code conversion

import unittest
import ../src/nimlana/errors
import ../src/nimlana/ffi

suite "Error Types and Raising":
  test "FFIError raising and catching":
    try:
      raiseFFIError("Test FFI error message")
      doAssert(false, "Should have raised FFIError")
    except FFIError as e:
      check e.msg == "Test FFI error message"
      check e of NimlanaError
    except CatchableError:
      doAssert(false, "Should have raised FFIError, not another exception")

  test "SerializationError raising and catching":
    try:
      raiseSerializationError("Test serialization error message")
      doAssert(false, "Should have raised SerializationError")
    except SerializationError as e:
      check e.msg == "Test serialization error message"
      check e of NimlanaError
    except CatchableError:
      doAssert(false, "Should have raised SerializationError, not another exception")

  test "VerificationError raising and catching":
    try:
      raiseVerificationError("Test verification error message")
      doAssert(false, "Should have raised VerificationError")
    except VerificationError as e:
      check e.msg == "Test verification error message"
      check e of NimlanaError
    except CatchableError:
      doAssert(false, "Should have raised VerificationError, not another exception")

  test "NetworkError raising and catching":
    try:
      raiseNetworkError("Test network error message")
      doAssert(false, "Should have raised NetworkError")
    except NetworkError as e:
      check e.msg == "Test network error message"
      check e of NimlanaError
    except CatchableError:
      doAssert(false, "Should have raised NetworkError, not another exception")

  test "Error inheritance from NimlanaError":
    # All errors should inherit from NimlanaError
    try:
      raiseFFIError("test")
    except NimlanaError:
      check true
    except CatchableError:
      doAssert(false, "FFIError should be catchable as NimlanaError")

    try:
      raiseSerializationError("test")
    except NimlanaError:
      check true
    except CatchableError:
      doAssert(false, "SerializationError should be catchable as NimlanaError")

    try:
      raiseVerificationError("test")
    except NimlanaError:
      check true
    except CatchableError:
      doAssert(false, "VerificationError should be catchable as NimlanaError")

    try:
      raiseNetworkError("test")
    except NimlanaError:
      check true
    except CatchableError:
      doAssert(false, "NetworkError should be catchable as NimlanaError")

  test "Error message preservation":
    let testMsg = "Detailed error message with context"
    try:
      raiseFFIError(testMsg)
    except FFIError as e:
      check e.msg == testMsg

    try:
      raiseSerializationError(testMsg)
    except SerializationError as e:
      check e.msg == testMsg

    try:
      raiseVerificationError(testMsg)
    except VerificationError as e:
      check e.msg == testMsg

    try:
      raiseNetworkError(testMsg)
    except NetworkError as e:
      check e.msg == testMsg

suite "Error Code Conversion":
  test "toNimlanaError - Success":
    let result = toNimlanaError(Success)
    check result == "Success"

  test "toNimlanaError - InvalidInput":
    let result = toNimlanaError(InvalidInput)
    check result == "Invalid input provided"

  test "toNimlanaError - VerificationFailed":
    let result = toNimlanaError(VerificationFailed)
    check result == "Signature verification failed"

  test "toNimlanaError - PanicCaught":
    let result = toNimlanaError(PanicCaught)
    check result == "Rust panic caught at FFI boundary"

  test "toNimlanaError - All error codes":
    # Test that all error codes are handled
    check toNimlanaError(Success) != ""
    check toNimlanaError(InvalidInput) != ""
    check toNimlanaError(VerificationFailed) != ""
    check toNimlanaError(PanicCaught) != ""

suite "Error Propagation":
  test "Error propagation through call stack":
    proc innerProc() =
      raiseFFIError("Inner error")

    proc middleProc() =
      innerProc()

    proc outerProc() =
      try:
        middleProc()
        doAssert(false, "Should have propagated error")
      except FFIError as e:
        check e.msg == "Inner error"

    outerProc()

  test "Error type preservation through propagation":
    proc raiseSerialization() =
      raiseSerializationError("Serialization failed")

    try:
      raiseSerialization()
      doAssert(false, "Should have raised error")
    except SerializationError:
      check true
    except CatchableError:
      doAssert(false, "Error type should be preserved")

suite "Error Edge Cases":
  test "Empty error message":
    try:
      raiseFFIError("")
      doAssert(false, "Should have raised error")
    except FFIError as e:
      check e.msg == ""

  test "Long error message":
    var longMsg = "A"
    for i in 0 ..< 1000:
      longMsg.add("B")
    try:
      raiseFFIError(longMsg)
      doAssert(false, "Should have raised error")
    except FFIError as e:
      check e.msg == longMsg
      check e.msg.len > 1000

  test "Error message with special characters":
    let specialMsg = "Error: \"quotes\" and 'apostrophes' and\nnewlines\tand\ttabs"
    try:
      raiseSerializationError(specialMsg)
      doAssert(false, "Should have raised error")
    except SerializationError as e:
      check e.msg == specialMsg

  test "Multiple error types in sequence":
    var errorCount = 0
    try:
      raiseFFIError("Error 1")
    except FFIError:
      inc errorCount

    try:
      raiseSerializationError("Error 2")
    except SerializationError:
      inc errorCount

    try:
      raiseVerificationError("Error 3")
    except VerificationError:
      inc errorCount

    try:
      raiseNetworkError("Error 4")
    except NetworkError:
      inc errorCount

    check errorCount == 4

