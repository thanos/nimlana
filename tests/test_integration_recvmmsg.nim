## Integration tests for recvmmsg batch packet receiving
## Tests the Linux-specific optimization

import unittest
import posix
import net
import ../src/nimlana/recvmmsg
import ../src/nimlana/tpu
import ../src/nimlana/types

when defined(linux):
  suite "recvmmsg Integration Tests":
    test "recvmmsg module loads on Linux":
      # Just verify the module compiles and types are available
      var result: RecvmmsgResult
      check result.packets.len == 0
      check result.count == 0

    test "recvmmsg receiveBatchPackets stub":
      # Create a UDP socket for testing
      let sockfd = socket(AF_INET, SOCK_DGRAM, 0)
      if sockfd >= 0:
        # Test batch receiving (will return empty on no data, which is fine)
        let result = receiveBatchPackets(sockfd, 32)
        check result.count >= 0
        check result.packets.len == result.count
        discard close(sockfd)

    test "TPU ingestor with recvmmsg support":
      # Test that TPU ingestor can work with recvmmsg
      let ingestor = newTPUIngestor(Port(8001))
      check ingestor.port == Port(8001)
      check ingestor.running == false
      
      # Verify ingestor structure is compatible with recvmmsg
      # (recvmmsg would be integrated into the recvLoop)

else:
  suite "recvmmsg Integration Tests (Non-Linux)":
    test "recvmmsg stub on non-Linux":
      # On non-Linux, recvmmsg should provide stub implementation
      let result = receiveBatchPackets(0, 32)
      check result.count == 0
      check result.packets.len == 0




