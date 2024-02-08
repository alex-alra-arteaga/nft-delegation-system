# Post second iteration thought process

- Found a very interesting vulnerability, which consisted on calling the contracts `delegate` and `revoke` functions when the NFT is in the registry when doing the multicall, being possible to delegate the NFT to another address, or to revoke the delegation, without the delegator's consent.
- A naive solution would be to prevent the multicall targets to be the registry, but the malicious contract could just transfer the NFT to itself and manipulate state from `delegate` and `revoke` functions.
- The correct solution is having reentrancy guards in this functions

- Also found out that I'll need a new approve to be done once the NFT is returned at the end of the multicall, since any `_transfer` clears the approvals.
- An `approvalForAll` would fix this issue, but coming with the trade-off of having to approve the registry for all the NFTs, which is riskier, but it is a practice widely adopted by NFT marketplaces.

## Conclusions

- The design looks functional for NFTs.
- Will go by now with the `setApprovalForAll` approach, since will be compatible with any Registry user, instead Openfort decides to use this delegation system internally for its Account Abstraction Wallets, I will use it.
- I've undertook a small trade-off to code selfexplainingness for more gas efficiency, by having the 'isDelegated' mapping removed by the `delegateeExpiration`, which merges the delegation time expiration and the delegation existence check in one single SSTORE.
- The alternative would be having a struct with a bool and a uint248, which would just a little bit more expensive due to 2 SSTORES, 1 cold (1000 gas) and 1 warm (100 gas), since both variable are packed inside the same bytes32 slot.