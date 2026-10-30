# Smart-contract bug classes — detection, primitive, fix

Master table. "Source pattern" = what you grep/read for; "primitive" = the attack you
build (in Exploit.t.sol first). Version claims: solc semantics vary — ranges stated.

## Table of contents

1. Reentrancy family
2. Arithmetic
3. Access control
4. Oracle & flash loans
5. Rounding / ERC4626
6. On-chain randomness
7. Signature bugs
8. delegatecall & proxies
9. CREATE2 / initcode
10. Gas griefing / DoS
11. Token quirks (fee-on-transfer, deflationary)
12. Ether edge cases
13. Key/ops hygiene & MEV

## 1. Reentrancy family

| Bug | Source pattern | Primitive | Fix (context) |
|---|---|---|---|
| Classic reentrancy | external call (`call{value:}` / token transfer) **before** the balance/mapping update | attacker contract `receive()`/fallback re-enters `withdraw` while balance still credited; drain in a loop | checks-effects-interactions; ReentrancyGuard |
| Cross-function reentrancy | shared state mutated by two functions, one makes an external call mid-way | reenter function B while inside A (e.g. withdraw → reenter `withdrawAll`) | same + per-state lock |
| Read-only reentrancy | a **view** function (usually oracle `quote()`) reads state that an external call leaves mid-update | call the vulnerable pair during your `receive()`, feed the stale view to a *second* protocol (swap/lend) that trusts it | reentrancy lock even on views, or finish state before any call |
| GoodSamaritan-style | token/`transfer` hook calls attacker code (`onERC721Received`, ERC777 tokens, some CTF tokens) | revert or re-enter inside the callback to corrupt the caller's accounting | never trust callback return path for accounting |

Detection order: inventory every external call → check what state is already updated at
that point → who controls the callee address. `tx.origin` used for auth is its own bug
(see access control) and also enables phishing-style reentrancy combos.

## 2. Arithmetic

| Bug | Source pattern | Primitive | Fix |
|---|---|---|---|
| Pre-0.8 overflow/underflow | `pragma ^0.5/0.6/0.7` without SafeMath; `balance -= amount` | wraparound: underflow a balance to ~2^256, overflow a counter past a check | SafeMath / solc ≥0.8 |
| Post-0.8 `unchecked` | `unchecked { ... }` blocks, especially loops and casting (`uint256(x)`, downcasts to `uint128/uint8`) | same wraparound inside the block | audit each unchecked op |
| Casting lossy | `uint256 -> uint8` etc. | truncate a big value to pass `require(x < 10)` then use full value | explicit bounds |
| Div/mul order | see §5 | | |

## 3. Access control

| Bug | Source pattern | Primitive | Fix |
|---|---|---|---|
| Unprotected `initializer()` | proxy pattern where implementation's initializer is callable on the *implementation* or re-initializable | call `initialize()` with yourself as owner/admin → take the proxy via upgrade or direct drain | initializerGuard (`Initializable` `_disableInitializers` in impl ctor) |
| Ownerless function | mutator with no `onlyOwner`/modifier | anyone calls it directly | add modifier |
| `tx.origin == owner` auth | any `tx.origin` comparison | phish owner into relaying any tx to your contract → your contract re-dispatches | use `msg.sender` |
| Missing role on upgrade | UUPS `upgradeTo` without authorization (or wrong check) | upgrade proxy to your malicious implementation | access control on `_authorizeUpgrade` |
| Front-runnable setup | constructor sets owner = `msg.sender` = deployer EOA, then transfer never happened; or `owner = address(0)` paths | nothing to exploit directly, but look for `onlyOwner` escapes when owner is 0x0 (calls from 0x0 impossible — dead code — or via `vm.prank(address(0))` in tests) | — |
| Public `setXxx` on config used as trust anchor (oracle addr, fee receiver) | | swap the anchor | |

## 4. Oracle & flash loans

| Bug | Source pattern | Primitive | Fix |
|---|---|---|---|
| Spot-price oracle | price computed as `reserveA/reserveB` of a UniswapV2-style pair (or `getReserves`) | manipulate reserves with a huge swap (flash-loan funded), read the inflated price, profit from the protocol trusting it, repay — all in one tx | TWAP oracles, Chainlink feeds with sanity bounds |
| Balance-based valuation | `token.balanceOf(pair) * something` | same: `balanceOf` is spot state | |
| Flash loan amplifier | any manipulation needing more capital than you have | `uint256 flashAmount; IERC20(asset).flashLoan(receiver, amount, data)` (Balancer) or UniswapV2 `flashSwap`; do manipulate → exploit → repay inside the callback | not a bug per se — the enabling primitive for the two rows above; CTF instances rarely check your profit source |
| Reserves-vs-liquidity sanity | price feed without min/max or staleness clamp | push price to absurd extreme | |

Flow in a test: one contract, one `testExploit`, `vm.startPrank` unnecessary — a single
tx. Use a Balancer flash loan (single-token, no fee) when the target chain's V2 pools
are thin.

## 5. Rounding / ERC4626

| Bug | Source pattern | Primitive | Fix |
|---|---|---|---|
| First-depositor share inflation | `shares = assets * totalSupply / totalAssets` with `totalSupply == 0`, or donation-boosted | deposit 1 wei to mint 1 share (or 1000 wei → 1000 shares), then **donate** assets directly to the vault so `totalAssets` jumps; everyone else's deposit now rounds to 0 shares; you redeem ~everything | mint `min` shares on first deposit (10^decimals); round against the user |
| Rounding direction | every `a * b / c` in share/quote math | attacker repeats the operation that rounds in their favor (deposit 1 wei, withdraw, loop) | audit rule: multiply before divide; round results against the attacker (floor what they receive, ceil what they pay) |
| `mul/div` truncation in swaps | x*y/z with small x | zero-cost or negative-cost swaps looped | same |

## 6. On-chain randomness

| Bug | Source pattern | Primitive | Fix |
|---|---|---|---|
| `block.timestamp` as seed | `uint(keccak256(abi.encodePacked(block.timestamp, ...)))` in the same block you act | run your guess and the "random" consume in one tx (off-chain precompute the seed) | commit-reveal or external randomness |
| `blockhash(n)` | only defined for the **last 256 blocks**; otherwise 0 | if `n` is older, the "random" is `0x0` — bet on the known value; if same-block, it's 0 too | |
| `prevrandao` (post-merge `block.difficulty`) | RANDOM opcode; **not** uniformly random — proposer-influenced | on a local fork: `vm.prevrandao(bytes32)` / mine predictable; on real chains, mev-builder influence | |

## 7. Signature bugs

| Bug | Source pattern | Primitive | Fix |
|---|---|---|---|
| ecrecover malleability | using raw `ecrecover` output without further checks | given one valid (v,r,s), `(v', r, n-s)` is also valid → forge a "different" signature for replay-resistant schemes that store sig hashes | require `s <= secp256k1n/2` (EIP-2) |
| Missing nonce | permit/voucher signed message with no nonce | replay the same signature twice | nonces mapping |
| Missing chainid / domain | EIP-712 without `chainid` or with wrong domain | replay across chains or forks (CTF: replay on the fork after organizers redeployed) | EIP-712 domain separation |
| Unordered nonce griefing | nonces checked as `== expected` instead of `>=` | front-run the victim's tx to burn their nonce | use `>=` / ordered queue |
| `ecrecover` returns 0 | result unchecked (address(0) comparison missing) | craft sig that recovers to 0x0 and passes `signer == recovered` when signer stored as 0 | check zero |

## 8. delegatecall & proxies

| Bug | Source pattern | Primitive | Fix |
|---|---|---|---|
| User-controlled delegatecall target | `target.delegatecall(data)` with `target` from calldata/storage | point it at a contract whose storage writes land in *your* context → overwrite `owner` slot | never delegatecall to untrusted code |
| selfdestruct in library context (pre-Cancun) | delegatecall into code containing `selfdestruct` | **pre-Cancun EVM**: selfdestruct executes in the *calling* context → kills the proxy and (pre-Shanghai/Berlin nuances aside) can force-send its balance; **Cancun (2024) restricts selfdestruct to contracts created in the same tx** — so on post-Cancun chains this primitive is dead for existing proxies | remove selfdestruct |
| Proxy storage collision | implementation address stored at slot 0 (non-EIP-1967 proxies) colliding with declared state | write the proxy's slot-0 var via a legit function → swap implementation | EIP-1967 slots / unstructured storage |
| EIP-1967 layout | see references/recon.md for slot constants | read `cast storage <proxy> 0x360894...` to find impl; if admin slot holds a claimable account → impersonate on fork | |
| UUPS unupgraded / uninitialized | impl lacks `_disableInitializers` in constructor | call `initialize` on the implementation directly, take it over (matters when impl holds state or is referenced) | initialize guards |
| Transparent proxy fallback clash | both proxy admin-functions and impl functions hit fallback | selector collision between `ProxyAdmin` iface and impl → route to unexpected side | RFC: transparent proxy separates by caller |
| Diamond facet confusion | selector → facet mapping add/replace with wrong args | call a removed-but-still-mapped facet, or exploit duplicate selectors | router tests |

## 9. CREATE2 / initcode

Address is deterministic: `keccak256(0xff ++ factory ++ salt ++ keccak256(initcode))[12:]`.

| Bug | Source pattern | Primitive |
|---|---|---|
| Initcode hash puzzle | challenge gives a target address + factory + salt, asks what initcode deploys there | brute-force initcode (offline) whose keccak makes the formula hit the address; `cast keccak`/forge loop |
| Metaprogramming redeploy | factory allows reuse of (salt, initcode-hash) after destruction | deploy → selfdestruct → redeploy same address with different code (pre-Cancun semantics; post-Cancun CREATE2 on a selfdestructed slot also blocked within limits) — restores state assumptions |
| Selector-shadowing via encodePacked | `abi.encodePacked` across dynamic types produces colliding encodings | craft calldata decoded differently than intended (see §13) |

## 10. Gas griefing / DoS

| Bug | Source pattern | Primitive | Fix |
|---|---|---|---|
| Unbounded loop over external calls | `for (i..n) token.transfer(list[i], ...)` | make n huge, or make one recipient revert → whole tx reverts | pull payments, cap iterations |
| Returnbomb | calling untrusted contract whose return data copies into memory (`returndatacopy` via Solidity `extcodecopy`-style abi decode of arbitrary length) | huge returndata burns callee gas | limit returndata size, low-level assembly return length check |
| Push-vs-pull payouts | payout loop `transfer`s to arbitrary addresses | register a contract that reverts (or consumes gas) on receive → block the last leg / brick `claim`-all | pull pattern |
| Revert-on-transfer DoS | reward path assumes `transfer` succeeds | be the reverting recipient; other players' txs fail (attack-defense flavor) | try/catch or pull |
| Block-gas-limit exclusion | any loop bounded by user-added length | same as unbounded loop | |

## 11. Token quirks

| Bug | Source pattern | Primitive | Fix |
|---|---|---|---|
| Fee-on-transfer accounting | `deposit(amount)` then internal `balanceOf(this)` diff assumed == amount | deposit x, credit x while contract received x-fee → accounting debt, withdraw more than share | measure actual received (balanceBefore/After) |
| Deflationary/elastic balances | token whose `balanceOf` shrinks on transfer or rebases | deposit → rebase/fee shrinks pool → withdrawal math overflows or shorts others | avoid assumptions on balance deltas |
| ERC721/1155 approval races | `setApprovalForAll` phishing; approvals in CTF wallets | check existing approvals on the victim: `cast call <nft> "isApprovedForAll(address,address)" <victim> <spender>` — if an old spender is trusted, impersonate that path | revoke approvals |
| Missing return-value check | `token.transfer()` bool ignored (pre-0.8 / non-standard tokens) | token returns false or nothing; protocol assumes success | SafeERC20 |
| `transfer` vs `transferFrom` confusion | allowance never decremented/checked | reuse stale allowance | |

## 12. Ether edge cases

| Bug | Source pattern | Primitive | Fix |
|---|---|---|---|
| Unintended ether receipt | contract assumes `address(this).balance == accounted` but balance is forceable | `selfdestruct` (pre-Cancun external force) or coinbase tx fees push ETH in → accounting breaks; also plain `payable` fallback | don't rely on exact balance invariants |
| Stuck-ETH constructor | constructor `payable` with no accounting | inflates `address(this).balance` before any shares exist → first-depositor math breaks (§5) | non-payable ctor + first-mint |
| `receive` required | contract `call{value}`s your exploit contract | implement `receive() external payable {}` (and expected ERC callbacks) or the send reverts | |
| `assert(this.balance == x)` patterns | | force-send via selfdestruct contract deployed fresh | |

## 13. Hygiene / ops / MEV

| Bug | Pattern | Primitive |
|---|---|---|
| Hardcoded private keys | challenge source or a past tx's `from` derived from a known test key (`vm.addr`, "0xdead..." style) | compute address from key, `vm.startPrank` on fork to act as deployer/owner |
| Whale impersonation on forks | any rich holder address | `anvil_impersonateAccount` + `--unlocked` (references/foundry.md) — works only locally |
| Commit-reveal front-run | commit phase with guess, reveal later | see commit in mempool, reveal adaptively; or reveal others' committed hashes |
| Sandwich/MEV | any on-chain price-dependent action | concept: attacker wraps your tx with buy/sell; in CTFs usually appears as "backrun the oracle update" or GoodSamaritan-style callback reentry (§1) |
| Auction end-time on block time | `block.timestamp >= end` logic | `vm.warp` past it on fork; or timestamp granularity (miners used to nudge ±, post-merge fixed per block) |
| Mapping iteration | code assumes iterable mapping (`mapping` has no length) | can never enumerate on-chain — but events + `cast logs` recover the keys off-chain |
| keccak "collision" claims | challenge hints hash collision | keccak256 collisions are infeasible — the real bug is using the *wrong* hash/encoding: `abi.encodePacked` of dynamic arrays, missing fields, `keccak256(abi.encode(...))` domain mistakes |
| ABI encoding confusion | selector shadowing: same 4-byte selector resolving to different signatures | lookup `cast 4byte <selector>` shows all candidates; craft calldata valid for both readings |
