# Foundry for CTFs — install, tools, cheatcodes, exact commands

## Install

```bash
curl -L https://foundry.paradigm.xyz | bash     # installs foundryup into ~/.foundry
foundryup                                        # installs forge cast anvil chisel (+ solc managers)
```

Binaries land in `~/.foundry/bin` — add to PATH. `foundryup` also pins/updates
versions (`foundryup -v nightly-<date>` if a challenge needs a specific one).
Idempotent wrapper: `skills/ctf-blockchain/scripts/setup-foundry.sh`.

Foundry downloads and manages solc versions automatically per `pragma` — do not
install solc yourself. `forge build` picks the version from each file's pragma.

## Tool map

| Tool | Role | Typical CTF use |
|---|---|---|
| `forge` | build, test, script | `forge test --fork-url ...`, `forge script --broadcast` |
| `cast` | CLI RPC client | calls, txs, storage reads, ABI/calldata encoding, chain queries |
| `anvil` | local EVM | fork the real chain, impersonate accounts, time travel |
| `chisel` | Solidity REPL | evaluate expressions (`chisel`, then e.g. `uint256(keccak256("x"))`) |

## Project setup

```bash
forge init --no-commit solve          # src/ test/ script/ + forge-std dependency
cd solve
```

- Put challenge source in `src/` (as-is if it compiles; otherwise write minimal
  interfaces `interface Target { function foo(uint256) external; }`).
- Remappings: forge auto-generates from dependencies (`forge remappings` to see);
  add to `remappings.txt` if the challenge repo expects different paths.
- `foundry.toml` essentials for CTFs:

```toml
[fuzz]
runs = 1000
[invariant]
runs = 100
# solc_version = "0.6.12"    # pin for legacy pragma if auto-resolution fails
```

## Fork testing flow (the core loop)

```bash
export RPC_URL=https://...            # archive-capable RPC of the target chain
anvil --fork-url $RPC_URL &           # fork at latest block; or --fork-block-number N
```

- 10 funded accounts, 10000 ETH each, keys printed at startup.
- Impersonate anyone (no key needed) via `cast rpc anvil_impersonateAccount 0x<addr>`
  then `cast send <to> "sig" args --from 0x<addr> --unlocked --rpc-url http://localhost:8545`.
- In forge tests none of this setup is needed — `vm.startPrank` covers it.
- Mining/time: default auto-mines each tx instantly. `--block-time 12` for fixed
  blocks. Advance with `cast rpc evm_increaseTime 3600 && cast rpc evm_mine`,
  `cast rpc evm_setNextBlockTimestamp 1730000000`, or cheatcodes in tests.
- Reset fork state: restart anvil (it re-forks from the RPC; local changes are gone).

### The test

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";

interface ITarget { function withdraw() external; function isSolved() external view returns (bool); }

contract ExploitTest is Test {
    address constant TARGET = 0x...;
    address constant VICTIM = 0x...;

    function testExploit() public {
        vm.deal(address(this), 10 ether);      // fund this contract
        vm.startPrank(VICTIM);                  // txs appear from VICTIM
        ITarget(TARGET).withdraw();
        vm.stopPrank();
        assertTrue(ITarget(TARGET).isSolved());
    }
}
```

```bash
forge test --fork-url $RPC_URL --match-path test/Exploit.t.sol -vvvv
```

- `-vvv` shows reverts, `-vvvv` full call traces with decoded args.
- No fork? Drop `--fork-url` and deploy the challenge contracts in `setUp()` — the
  Ethernaut/DVD offline pattern.
- Fuzz any parameter: `function testX(uint128 amount) public { vm.assume(amount > 1); ... }`.

## Cheatcodes (forge-std/Test)

| Cheatcode | Effect |
|---|---|
| `vm.deal(addr, 1 ether)` | set an address's ETH balance |
| `vm.prank(addr)` | next call's `msg.sender` = addr |
| `vm.startPrank(addr)` / `vm.stopPrank()` | all calls in between from addr |
| `vm.roll(blockNum)` | set block number |
| `vm.warp(ts)` | set block timestamp |
| `vm.expectRevert()` | next call must revert (assert revert paths) |
| `vm.label(addr, "Name")` | readable traces |
| `vm.mockCall(addr, calldata, retdata)` | stub an external contract's response (fake oracle) |
| `vm.sign(pk, digest)` | produce a signature (test replay/malleability) |
| `vm.addr(pk)` | address for a private key |
| `vm.setStorageAt(addr, slot, bytes32)` | overwrite raw storage (verify a slot hypothesis) |
| `vm.assume(cond)` | constrain fuzz inputs |

## cast — exact encodings and lookups

```bash
# ABI encoding / decoding
cast calldata "transfer(address,uint256)" 0xabc 1000     # encode calldata offline
cast calldata-decode "transfer(address,uint256)" 0xa9059cbb...   # decode args
cast abi-encode "f(uint256)" 42                          # raw encoding for vm.setStorageAt etc.
cast sig "transfer(address,uint256)"                     # selector 0xa9059cbb
cast keccak 0x1234                                       # keccak256 of hex bytes (for text-hashing puzzles use chisel: keccak256("x"))

# selector -> name (openchain / 4byte directory lookup, network required)
cast 4byte 0xa9059cbb                                    # prints candidate signatures
cast 4byte-event 0xddf252ad...                           # event signature lookup
cast 4byte-decode 0xa9059cbb0000...                      # decode calldata using directory match

# state
cast storage <addr> <slot> --rpc-url $RPC_URL            # raw 32-byte slot
cast proof <addr> <slot> --rpc-url $RPC_URL              # merkle proof (storage manipulation targets)
forge inspect <ContractName> storageLayout                # source-level slot map (local project)

# calls and txs
cast call <addr> "balanceOf(address)" <me> --rpc-url $RPC_URL          # read-only eth_call
cast send <addr> "deposit()" --value 1ether --rpc-url $RPC_URL --private-key 0x...
cast send <addr> 0x<rawcalldata> --rpc-url $RPC_URL --private-key 0x... # pre-encoded

# chain info
cast chain-id --rpc-url $RPC_URL
cast balance <addr> --rpc-url $RPC_URL ; cast nonce <addr> --rpc-url $RPC_URL
cast block-number --rpc-url $RPC_URL ; cast block latest --rpc-url $RPC_URL
cast code <addr> --rpc-url $RPC_URL                      # deployed bytecode
cast logs 'OwnershipTransferred(address,address)' --from-block 0 --rpc-url $RPC_URL
cast run <txhash> --rpc-url $RPC_URL                     # replay a tx with a full trace
```

Units: `cast --from-wei 1000000000000000000`, `cast --to-wei 1.5`, `cast --to-unit 1.5 gwei`.
Address/int conversions: `cast --to-hex 42`, `cast --to-dec 0x2a`.

## forge script — broadcast to the real chain

```bash
forge script script/Exploit.s.sol --rpc-url $RPC_URL --broadcast --private-key 0x...
# add --slow to wait one block per tx (safer on finality-delayed chains)
# add --verify (needs explorer API key) if you want verified source
```

Script skeleton (full template: `skills/ctf-blockchain/scripts/Exploit.s.sol`):

```solidity
import "forge-std/Script.sol";
contract Exploit is Script {
    function run() external {
        address target = vm.envAddress("TARGET");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        // calls here become real on-chain txs, in order
        vm.stopBroadcast();
    }
}
```

Sequence for one-shot instances: get the test fully green first, then broadcast once.

## Debugging tips

- `forge test -vvvv` traces decode calls when the interface is in the project.
- `cast run <txhash>` on a past failing tx (e.g. another player's attempt) shows the
  revert point — free recon.
- `forge snapshot` / gas reports are noise for CTFs; ignore.
- If legacy pragma (`^0.6`, `^0.7`) fails to resolve: pin `solc_version` in
  foundry.toml or add `--no-auto-detect` with an explicit `--use solc:0.6.12`.
