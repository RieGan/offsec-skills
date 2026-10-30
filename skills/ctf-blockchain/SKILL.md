---
name: ctf-blockchain
description: Use when a challenge involves blockchain, EVM, Solidity or Vyper source, smart contracts, an RPC URL, bytecode strings (0x6080604052...), wallet private keys, wei/ETH amounts, Foundry/forge/cast/anvil, Hardhat, web3/ethers, Ethernaut or Damn Vulnerable DeFi, DeFi pools/oracles/flash loans, proxy upgrades, or "get the flag out of contract 0x...".
---

# CTF blockchain — EVM/Solidity exploitation

Core loop: **understand the contract → fork the chain locally → break it in a Foundry
test → replay the same calls against the real chain.** Never develop against the live
target; CTF instances are usually per-player and reverting txs waste nothing but time,
but a buggy live exploit can burn your one shot.

Operating rules (remote gate, untrusted artifacts, install policy) live in the `ctf`
router skill — they apply to every RPC connection and challenge artifact here.

## Triage (first 5 minutes)

Inventory what the challenge gave you:

| Given | Meaning | First move |
|---|---|---|
| RPC URL + contract address | live instance, per-player or shared | `cast chain-id`, `cast code <addr>`, explorer for source |
| Verified source on explorer / `.sol` in dist | full-audit path | read `references/bugclasses.md`, inventory external calls |
| Only bytecode `0x...` | reverse path | `cast 4byte` selectors, heimdall decompile — `references/recon.md` |
| Private key + funded account | you are an actor, not just attacker | check `cast balance`, `cast nonce` |
| "Get flag when X happens" | flag is emitted/triggered on-chain | `cast logs --from-block 1` for the flag event |
| Private geth dev chain (chain-id 1337 etc.) | organizer chain, gas often 0 | `references/chains.md` |
| No remote at all (Ethernaut-style local, or `.sol` + tests) | offline solve | `forge init`, test-first flow |

Questions to answer before touching the keyboard (all answerable via `references/recon.md`):

1. Which chain? (`cast chain-id`, explorer domain)
2. Who are the interesting addresses? (deployer, other players, the "victim" wallet, token/pair contracts)
3. Is the target a proxy? (EIP-1967 slots — precomputed constants in `references/recon.md`)
4. What is the win condition — drain ETH/tokens, become owner, call a `getFlag()` gated by a check, or emit an event the organizer listens for?
5. What does the tx history show? (intended flow, other players' failed attempts)

## Playbook (fork → test → mainnet)

Prereq: Foundry installed — `scripts/setup-foundry.sh` (idempotent) or see
`references/foundry.md` §install. Foundry manages its own solc versions automatically;
never install solc by hand.

```bash
mkdir -p work/<event>/blockchain-<name>/{dist,solve}           # router workspace layout
cd work/<event>/blockchain-<name>/solve
forge init --no-commit .            # creates src/ test/ script/ foundry.toml
export RPC_URL=<challenge rpc>      # archive RPC for forks (Alchemy/Infura/public)
```

### Step 1 — fork the target chain locally

```bash
anvil --fork-url $RPC_URL           # auto-detects latest block; HTTP on :8545
```

You get 10 deterministically-funded accounts (10000 ETH each, private keys printed on
startup) at the fork's latest state — the real target contract, real balances, zero
risk. To act **as an existing address** (the victim, the deployer, a whale):

```bash
cast rpc anvil_impersonateAccount 0x<victim>
cast send <target> "transfer(address,uint256)" <args> --from 0x<victim> --unlocked
# in forge tests: vm.startPrank(0x<victim>) does the same, no impersonation RPC needed
```

Mining modes: default = instant (auto-mine per tx); `anvil --fork-url $RPC_URL --block-time 12`
for fixed intervals; time travel with `cast rpc evm_increaseTime 3600` / `cast rpc evm_mine`.
Gas price 0 chains: `anvil --fork-url $RPC --gas-price 0`.

### Step 2 — write the exploit as a test

Copy target sources (or their interfaces) into `src/`, then `test/Exploit.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";

contract ExploitTest is Test {
    address constant TARGET = address(0x1234...);   // real instance address

    function setUp() public {
        // optional: vm.deal(address(this), 1 ether); vm.prank(0x<victim>); ...
    }

    function testExploit() public {
        vm.startPrank(0x<attacker-or-impersonated>);
        Target(TARGET).vulnerableFunction{value: 1 ether}(args);
        vm.stopPrank();
        // assert win condition: balances, owner, flag event
        assertTrue(Target(TARGET).isSolved());
    }
}
```

```bash
forge test --fork-url $RPC_URL --match-path test/Exploit.t.sol -vvvv
```

Fuzz/invariant harnesses, cheatcode table, and cast calldata encodings:
`references/foundry.md`.

### Step 3 — replay against the real chain

When the test passes, run the identical logic via a script — template at
`scripts/Exploit.s.sol`:

```bash
export TARGET=0x<instance>
export PRIVATE_KEY=0x<your funded key>
forge script script/Exploit.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

Simple exploits are often one or two plain txs — `cast send` needs no project at all:

```bash
cast send $TARGET "unlock(uint256)" 42 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

Gate: this step touches the remote instance — explicit user go-ahead per the `ctf`
router. If the instance is one-shot (selfdestruct, `solved()` latching), verify the
test covers every revert path first.

### Step 4 — collect the flag

Usually: an event, a `getFlag()`/`solved()` view, or the organizer's bot notices the
condition. `cast logs 'Flag*(*)' --from-block <deploy-block> --rpc-url $RPC_URL --json`,
or the platform's "get flag" button after on-chain win.

## Bug-class quick index

Full table (bug → source detection pattern → exploit primitive → fix):
`references/bugclasses.md`. Memory hooks:

| Smell in source | Likely class |
|---|---|
| external call before state update | reentrancy |
| spot price from pair reserves | oracle manipulation (flash-loan scale) |
| arithmetic in `unchecked` or solc <0.8 | overflow/underflow |
| `initializer()` with no access control | hijack proxy implementation |
| shares = msg.value * totalShares / totalAssets, first depositor | ERC4626 share inflation |
| `block.timestamp` / `blockhash` / `prevrandao` as randomness | predictable "random" |
| `ecrecover` without `s <= n/2` check or nonce | signature replay/malleability |
| `delegatecall` to user-controlled address | storage hijack / pre-Cancun selfdestruct |
| `for` over caller-supplied array, external call per iteration | gas griefing |
| tokens forwarded then balance-diffed | fee-on-transfer accounting |

## References

- `references/foundry.md` — install, tool map (forge/cast/anvil/chisel), project setup,
  cheatcode table, exact cast calldata/4byte/storage encodings, fork testing flow,
  forge script broadcasting.
- `references/bugclasses.md` — the bug table: reentrancy (incl. read-only/oracle),
  oracle/flash-loan, ERC4626 rounding, access control, signature bugs, proxy pitfalls
  (EIP-1967, UUPS, collisions, CREATE2), DoS/gas-griefing, token quirks, MEV.
- `references/recon.md` — explorer/bytecode recon: EIP-1967 slot constants table,
  storage dumps, selector decoding, heimdall decompilation, event/tx history, fork
  state inspection.
- `references/chains.md` — practice ladder (Ethernaut, Damn Vulnerable DeFi), private
  organizer chains (geth dev, chain-id, zero-gas), per-player instance platforms,
  testnet faucets, L2 nuances.

## Toolbox

| Tool | Install | Purpose |
|---|---|---|
| `foundryup` | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` (or `scripts/setup-foundry.sh`) | installs/updates forge, cast, anvil, chisel; manages solc automatically |
| `forge` | via foundryup | test framework, scripts, `forge inspect <C> storageLayout` |
| `cast` | via foundryup | CLI RPC client: call/send/storage/logs/4byte/calldata |
| `anvil` | via foundryup | local chain + chain forking + impersonation |
| `chisel` | via foundryup | Solidity REPL for scratching expressions |
| `heimdall` | `cargo install heimdall-rs` | bytecode decompiler (bytecode-only challenges) |
| `.venv` (eth-account/web3 optional) | `uv pip install --python .venv/bin/python eth-account web3` | only if a challenge demands Python signing; foundry usually suffices |
