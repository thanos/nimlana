## Mock tests for gRPC Block Engine client
## Tests the gRPC functionality without actual network calls

import unittest
import chronos
import net
import ../src/nimlana/types
import ../src/nimlana/blockengine
import ../src/nimlana/bundle
import ../src/nimlana/buffer
import ../src/nimlana/tpu
import ../src/nimlana/errors
import ../src/nimlana/borsh

# Mock gRPC client for testing
type
  MockGrpcResponse* = object
    accepted*: bool
    bundleId*: string
    errorMessage*: string

  MockBlockEngineGrpcClient* = ref object
    client*: BlockEngineClient # Composition instead of inheritance
    mockResponses*: seq[MockGrpcResponse]
    responseIndex*: int
    connectionAttempts*: int
    bundlesSent*: seq[Bundle]
    shouldFailConnect*: bool
    shouldFailSend*: bool

proc newMockBlockEngineGrpcClient*(
    endpoint: string = "mock.jito.wtf:443"
): MockBlockEngineGrpcClient =
  result = MockBlockEngineGrpcClient(
    client: newBlockEngineClient(endpoint),
    mockResponses: @[],
    responseIndex: 0,
    connectionAttempts: 0,
    bundlesSent: @[],
    shouldFailConnect: false,
    shouldFailSend: false,
  )

proc connect*(client: MockBlockEngineGrpcClient) {.async.} =
  ## Mock gRPC connection
  inc client.connectionAttempts
  
  if client.shouldFailConnect:
    raiseNetworkError("Mock gRPC connection failed")
  
  # Simulate connection delay
  await sleepAsync(milliseconds(10))
  await client.client.connect()

proc sendBundle*(client: MockBlockEngineGrpcClient, bundle: Bundle): Future[bool] {.async.} =
  ## Mock gRPC bundle submission
  if not client.client.connected:
    await client.connect()
  
  if client.shouldFailSend:
    raiseNetworkError("Mock gRPC send failed")
  
  # Store bundle for verification
  client.bundlesSent.add(bundle)
  
  # Simulate network delay
  await sleepAsync(milliseconds(5))
  
  # Return mock response
  if client.responseIndex < client.mockResponses.len:
    let response = client.mockResponses[client.responseIndex]
    inc client.responseIndex
    result = response.accepted
  else:
    # Default: accept all bundles
    result = true

proc disconnect*(client: MockBlockEngineGrpcClient) =
  client.client.disconnect()

suite "gRPC Mock Tests - Connection":
  test "Mock gRPC client creation":
    let client = newMockBlockEngineGrpcClient("test.jito.wtf:443")
    check client.client.endpoint == "test.jito.wtf:443"
    check client.client.connected == false
    check client.connectionAttempts == 0

  test "Mock gRPC connect":
    let client = newMockBlockEngineGrpcClient()
    check client.client.connected == false
    waitFor client.connect()
    check client.client.connected == true
    check client.connectionAttempts == 1

  test "Mock gRPC connect failure":
    let client = newMockBlockEngineGrpcClient()
    client.shouldFailConnect = true
    expect(NetworkError):
      waitFor client.connect()
    check client.client.connected == false
    check client.connectionAttempts == 1

  test "Mock gRPC auto-connect on send":
    let client = newMockBlockEngineGrpcClient()
    check client.client.connected == false
    
    let bundle = Bundle(
      transactions: @[@[0x01.byte]],
      tipAccount: zeroPubkey(),
      tipAmount: 1000'u64,
    )
    
    discard waitFor client.sendBundle(bundle)
    check client.client.connected == true
    check client.connectionAttempts == 1

  test "Mock gRPC disconnect":
    let client = newMockBlockEngineGrpcClient()
    waitFor client.connect()
    check client.client.connected == true
    client.disconnect()
    check client.client.connected == false

suite "gRPC Mock Tests - Bundle Submission":
  test "Mock gRPC send bundle":
    let client = newMockBlockEngineGrpcClient()
    let bundle = Bundle(
      transactions: @[@[0x01.byte, 0x02.byte]],
      tipAccount: zeroPubkey(),
      tipAmount: 5000'u64,
    )
    
    let accepted = waitFor client.sendBundle(bundle)
    check accepted == true
    check client.bundlesSent.len == 1
    check client.bundlesSent[0].transactions.len == 1
    check client.bundlesSent[0].tipAmount == 5000'u64

  test "Mock gRPC send multiple bundles":
    let client = newMockBlockEngineGrpcClient()
    
    for i in 0 ..< 5:
      let bundle = Bundle(
        transactions: @[@[i.byte]],
        tipAccount: zeroPubkey(),
        tipAmount: (i * 1000).uint64,
      )
      discard waitFor client.sendBundle(bundle)
    
    check client.bundlesSent.len == 5
    check client.bundlesSent[0].tipAmount == 0'u64
    check client.bundlesSent[4].tipAmount == 4000'u64

  test "Mock gRPC send bundle with custom response":
    let client = newMockBlockEngineGrpcClient()
    client.mockResponses = @[
      MockGrpcResponse(accepted: true, bundleId: "bundle-1", errorMessage: ""),
      MockGrpcResponse(accepted: false, bundleId: "", errorMessage: "Invalid bundle"),
      MockGrpcResponse(accepted: true, bundleId: "bundle-3", errorMessage: ""),
    ]
    
    let bundle1 = Bundle(transactions: @[], tipAccount: zeroPubkey(), tipAmount: 0)
    let bundle2 = Bundle(transactions: @[], tipAccount: zeroPubkey(), tipAmount: 0)
    let bundle3 = Bundle(transactions: @[], tipAccount: zeroPubkey(), tipAmount: 0)
    
    let result1 = waitFor client.sendBundle(bundle1)
    let result2 = waitFor client.sendBundle(bundle2)
    let result3 = waitFor client.sendBundle(bundle3)
    check result1 == true
    check result2 == false
    check result3 == true

  test "Mock gRPC send bundle failure":
    let client = newMockBlockEngineGrpcClient()
    client.shouldFailSend = true
    
    let bundle = Bundle(transactions: @[], tipAccount: zeroPubkey(), tipAmount: 0)
    expect(NetworkError):
      discard waitFor client.sendBundle(bundle)

  test "Mock gRPC send bundle with multiple transactions":
    let client = newMockBlockEngineGrpcClient()
    let bundle = Bundle(
      transactions: @[
        @[0x01.byte, 0x02.byte],
        @[0x03.byte, 0x04.byte],
        @[0x05.byte, 0x06.byte],
      ],
      tipAccount: zeroPubkey(),
      tipAmount: 10000'u64,
    )
    
    let accepted = waitFor client.sendBundle(bundle)
    check accepted == true
    check client.bundlesSent[0].transactions.len == 3

  test "Mock gRPC send bundle with custom tip account":
    let client = newMockBlockEngineGrpcClient()
    var customTip = zeroPubkey()
    customTip[0] = 0xAA
    customTip[31] = 0xBB
    
    let bundle = Bundle(
      transactions: @[@[0x01.byte]],
      tipAccount: customTip,
      tipAmount: 50000'u64,
    )
    
    discard waitFor client.sendBundle(bundle)
    check client.bundlesSent[0].tipAccount == customTip
    check client.bundlesSent[0].tipAccount[0] == 0xAA
    check client.bundlesSent[0].tipAccount[31] == 0xBB

suite "gRPC Mock Tests - Integration":
  test "Mock gRPC with bundle parsing integration":
    let client = newMockBlockEngineGrpcClient()
    
    # Create a bundle packet
    var bundleData: seq[byte] = @[]
    bundleData.add(0x01.byte) # BundleMarker
    bundleData.add(borshSerializeU32(70'u32)) # Transaction length
    
    # Add transaction: 1 signature + 64 bytes sig + 5 bytes message
    bundleData.add(1.byte)
    for i in 0 ..< 64:
      bundleData.add(i.byte)
    for i in 0 ..< 5:
      bundleData.add(i.byte)
    
    let buffer = newSharedBufferFromBytes(bundleData)
    let packet = IngestedPacket(
      data: buffer,
      header: BundleMarker,
      timestamp: 0.0,
      source: initTAddress("127.0.0.1", Port(1234)),
    )
    
    # Parse and send
    let parsedBundle = parseBundle(packet)
    let bundle = toBundle(parsedBundle)
    let accepted = waitFor client.sendBundle(bundle)
    
    check accepted == true
    check client.bundlesSent.len == 1
    check client.bundlesSent[0].transactions.len == 1

  test "Mock gRPC connection retry":
    let client = newMockBlockEngineGrpcClient()
    client.shouldFailConnect = true
    
    # First attempt fails
    expect(NetworkError):
      waitFor client.connect()
    
    # Retry succeeds
    client.shouldFailConnect = false
    waitFor client.connect()
    check client.client.connected == true
    check client.connectionAttempts == 2

