# On-chain recon — from RPC + address to full picture

Given: RPC URL, contract address(es), sometimes source. Goal before writing any
exploit: know the chain, the contract's storage layout, its tx history, and the win
condition. Remote gate from the `ctf` router applies to every RPC/explorer hit.

## 1. Chain & accounts

```bash
export RPC_URL=...
cast chain-id --rpc-url $RPC_URL     # 1=mainnet, 11155111=sepolia, 17000=holesky, 1337/31337=local dev
cast block-number --rpc-url $RPC_URL
cast balance <addr> --rpc-url $RPC_URL
cast nonce <addr> --rpc-url $RPC_URL  # how active an account is
cast code <addr> --rpc-url $RPC_URL   # empty "0x0x" => EOA, else contract
```

Block explorer for that chain (mainnet/sepolia/holesky → etherscan.io; others have
their own — the RPC's L1 usually tells you; CTF private chains have none). Explorer
gives: verified source, tx history, event logs, contract creator. Fetching verified
source programmatically needs an explorer API key (`cast etherscan-verify` is for
*posting* verification, not fetching — don't confuse them; use the web UI to read).

## 2. Proxy detection — EIP-1967 storage slots

If `cast code` is non-empty and the explorer shows a proxy, read the standard slots:

| Slot name | Value (constant) |
|---|---|
| implementation | `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` |
| admin | `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103` |
| beacon | `0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50` |

(each = `bytes32(uint256(keccak256('eip1967.proxy.<name>')) - 1)`, bumped by -1 so the
slot never collides with a Solidity-declared variable.)

```bash
cast storage <proxy> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $RPC_URL
# value holds the implementation address; read the admin slot to see who upgrades
```

Non-standard proxies store the impl at slot 0 or in a declared var — check the source,
and `forge inspect <Contract> storageLayout` in a local project for the exact map.
A `0x...beef` suffix pattern in the fallback bytecode signals an EIP-1967 proxy.

## 3. Storage slot dumping

Loop slots until they go empty (mostly the first ~20 matter in CTFs):

```bash
for s in $(seq 0 15); do
  v=$(cast storage <addr> $s --rpc-url $RPC_URL)
  echo "slot $s: $v"
done
```

Reading values: low 32 hex chars = uint in slot; packed structs share a slot
(`uint128,uint128` = two 16-byte halves). `vm.setStorageAt` in a *test* proves a slot
hypothesis before you spend a real tx. Mappings/arrays: slot holds only
length/count for arrays; mapping values live at `keccak256(h(k) . slot)` (compute with
`cast index <keyType> <key> <slot>`, e.g. `cast index address 0xabc... 3`).

## 4. Function-selectors and calldata

```bash
cast sig "withdraw(uint256)"                     # selector for a name you know
cast 4byte 0x2e1a7d4d                            # selector -> candidates (network lookup)
cast calldata-decode "f(uint256,address)" 0x2ac...   # decode tx input you found
```

Find all selectors in bytecode: `cast disassemble <bytecode>` and grep PUSH4 values,
then `cast 4byte` each — a fast function inventory for unverified contracts.

## 5. Events and tx history

```bash
# all events ever emitted by the target
cast logs --address <addr> --from-block 0 --rpc-url $RPC_URL

# flag-shaped events
cast logs 'Flag*(*)' --from-block 0 --rpc-url $RPC_URL
# named topics: cast logs 'OwnershipTransferred(address,address)' --from-block 0

# decode an event's data payload (abi-encoded)
cast calldata-decode "<types>" <datahex>
# unknown event topic hash -> signature
cast 4byte-event 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
```

Tx history (explorer UI, or RPC receipts): what the deployer called in what order is
the *intended* flow; other players' failed txs are free recon — `cast run <txhash>
--rpc-url $RPC_URL` replays with a trace showing the revert.

## 6. Bytecode-only targets

No verified source:

1. **heimdall** (decompiler): `cargo install heimdall-rs`, then
   `heimdall decompile --address 0x... --rpc-url $RPC_URL` (or
   `heimdall decompile --bytecode 0x...`) → annotated pseudo-Solidity + selector
   resolution. Also `heimdall disassemble`.
2. Online decompilers (dedaub.com, paladin signatures) — fine for CTF source reading,
   mind the untrusted-artifact rule: don't paste anything secret, only public bytecode.
3. `cast disassemble` for raw opcode-level reading.
4. Match against known sources: keccak of deployed bytecode vs the same compiler
   version of a public repo (organizers often reuse Ethernaut/DVD logic).

## 7. Fork state inspection

After `anvil --fork-url $RPC_URL`, everything above works identically against
`http://localhost:8545` — but you can also *mutate* freely:

```bash
cast rpc anvil_setStorageAt <addr> <slot> <value>
cast rpc anvil_setBalance <addr> 0x56bc75e2d63100000
cast rpc anvil_impersonateAccount <addr>
cast rpc evm_snapshot   # returns id
cast rpc evm_revert <id>
```

Use snapshots before a risky exploit attempt on the local fork; restart anvil to reset
completely. Note a fork only mirrors the chain at fork time — later mainnet txs
(including the organizer deploying something new) need a re-fork.

## 8. Source review checklist (when source is given)

Order matters; this finds 90% of CTF blockchain bugs:

1. **External calls inventory**: every `call`, `.transfer`, `.send`, token transfer,
   `delegatecall`. For each: who controls the target? What state is updated before it?
2. **Order analysis**: check-effects-interactions violations → reentrancy (bugclasses §1).
3. **Access map**: list every function with its modifier; find ones with none; check
   `initialize`/constructor paths; check `tx.origin`.
4. **What the constructor sets**: owner, roles, initial balances — impersonatable on a fork.
5. **Math audit**: `unchecked`, downcasts, mul-before-div, rounding direction, first-depositor.
6. **Randomness**: block.timestamp/blockhash/prevrandao usage.
7. **Proxy?** → §2 above, then read the *implementation*, not just the proxy.
8. **Win condition**: find `solved()`/`getFlag()`/event the platform watches — work
   backwards from it to the cheapest reachable precondition.
