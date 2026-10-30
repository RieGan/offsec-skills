# Chains & practice environments

## Practice ladder (free, offline-friendly)

| Platform | What it teaches | Local flow |
|---|---|---|
| Ethernaut (ethernaut.openzeppelin.org) | one bug per level, beginner→mid | each level is a contract + instance button; either use their Rinkeby-era flow or deploy the level source yourself in a forge `setUp()` — all levels are on GitHub (OpenZeppelin/ethernaut) |
| Damn Vulnerable DeFi (damnvulnerabledefi.xyz) | mid→hard, DeFi-flavored (flash loans, oracles, proxies, lending) | ships as a Foundry repo: `git clone` the challenge repo, `forge test --match-path test/<Level>.t.sol` — solve by editing `test/` until green; no RPC needed |
| Paradeigrachron / older "Damn Vulnerable" sets | audit-style | source-only, forge init around them |

Both platforms' sources are public and run entirely locally — best first stop when
learning a bug class from `bugclasses.md`. CTF platforms (CTFd-style or custom) with
blockchain challenges are the second shape:

## CTF platform shapes

| Shape | Given | Mechanics |
|---|---|---|
| Per-player instance | RPC URL, instance contract address, your funded private key | platform deploys a fresh instance when you click "launch"; solve it, then click "get flag" (bot checks on-chain condition). Instances usually expire — don't burn one-shot bugs early: fork first |
| Shared chain | RPC URL + fixed contract | everyone attacks the same instance; expect front-running and sabotage (bugclasses §13) |
| Private organizer chain | geth dev-mode URL, chain-id 1337 (or 31337 = anvil) | often zero-gas, instant mining; only the organizer's chain has the flag bot |
| Source-only, no remote | `.sol` + tests, "make the test pass" | flag from test output or organizer verifies offline |

## Private organizer chains (geth dev)

- Configure: just `--rpc-url <url>` on every cast/forge/anvil call (or `export
  RPC_URL`). Chain sanity: `cast chain-id --rpc-url $RPC_URL`.
- Gas: dev chains often accept price 0 — `cast send ... --gas-price 0`, or
  `anvil --fork-url $RPC --gas-price 0` when forking one.
- Instant vs interval mining: `cast block-number` twice a few seconds apart; if it
  never moves without txs, blocks mine on demand — `block.timestamp`-based logic
  needs explicit mining (`cast rpc evm_mine` won't exist on geth; send any dummy tx,
  or set `--period` on the organizer's side you can't control — just send txs).
- If they hand you a funded key: `cast send` works directly; no fork needed for
  small stuff, but still fork for exploit development.

## Testnets

| Network | Chain id | Faucet |
|---|---|---|
| Sepolia | 11155111 | sepolia faucet(s) via Google/Alchemy/Infura accounts, or social faucets |
| Holesky | 17000 | holesky faucet pages (same providers) |

Faucets need an account/API key or a GitHub login; ask the user before signing up for
anything. Practice platforms increasingly hand you testnet ETH with the instance —
prefer that.

## L2 nuances (Optimism/Arbitrum targets)

- Sequencer: transactions are ordered by the sequencer, not a public mempool on
  OP-mainnet-style stacks — front-running surface differs; finality to L1 is delayed.
- `block.timestamp` on L2 ≈ L1 time; `blockhash`/`prevrandao` semantics differ from
  L1 — do not port randomness exploits blindly.
- Gas: L1 data fee component; `--gas-price 0` never applies on public L2s.
- Forking works the same: `anvil --fork-url <l2-rpc>`.

## Checklist: pointing foundry at an event

```bash
export RPC_URL=<given>                          # organizer RPC or public endpoint
cast chain-id --rpc-url $RPC_URL                # record chain + explorer in notes.md
cast code <instance> --rpc-url $RPC_URL         # confirm deployed
anvil --fork-url $RPC_URL &                     # local replica; develop here
```

Remote gate: these RPC reads are remote connections — get user go-ahead per the `ctf`
router before first contact with an event host.
