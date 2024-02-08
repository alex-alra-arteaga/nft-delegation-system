# Initial first principles thought process

- To get the NFT benefits, the delegatee must be able to prove that it has the right to use the NFT.
- Normally ownership of NFT is proven by a call to the `ownerOf` function. An example of this are UniswapV3 liquidity positions, the `NonFungiblePositionManager` has the modifier `isAuthorizedForToken`, which checks the owner via `ownerOf`, and probes that `msg.sender` is either the owner or an approved operator.
- We can't change this function since we want our design to be compatible with any deployed NFT contract.
- If the delegatee wants to be able to, for example, collect fees in the name of the NFT, it must be able to prove that it has the right to do so, but without ownership rights.

- A solution that has came to my mind that I have to yet validate is to have a registry that maps delegators to certain NFTs, this smart contract would have ownership rights over the NFTs and a multicall function only callable by the delegatee. That would allow it to perform certain actions on behalf of the NFT.

- To ensure that the delegatee can't transfer the NFT to anyone else, we can have a ownership check at the end of the multicall function, but this doesn't solves the possible problem that the delegatee could approve an operator to transfer the NFT to itself.

- There are two different types of approvals. `approve()` lets an account move a single tokenId, while `setApprovalForAll()` marks an address as an operator to move all tokenIds.

- By approving the `tokenId` to `address(0)` at the end of the multicall function we can clear any malicious operator approval.

- But due to the nature of `setApprovalForAll` function, consisting of a mapping from `address` (owner) to `address` (spender) to `bool`, we can't clear all the approvals for the various spenders, since it is computationally impossible to iterate over all the possible addresses, due to a mapping being a key->value data structure with no iterator.

- This could make all the same tokenIds of the same NFT contract address vulnerable.
- The only way to call the `setApprovalForAll` function is by the `msg.sender` being the registry, so, directly through the multicall, to have a check that there isn't any `setApprovalForAll` function selector in the calldata or preventing the target to be the NFT collection could be enough to prevent this attack.

## Initial conclusions

So far this look promising.

### Design trade-offs
The design trade-offs to be made are clear, either:
    - An expensive `findSubStr operation`, which would scale linearly with the size of the calldata.
Or: 
    - No possible interaction with it's own NFT contract for call ops (even that I don't see any real application inconvenience, also staticcall can be used for read operations if it is needed).
    · This would remove the need for a check for ownership at the end of the multicall function, and the need for a check for the `setApprovalForAll` function selector in the calldata or setting the token approvals to 0 if the operator is different than the delegator.

At the moment, I think that the second option is a no-brainer.

### What I don't like about this design
This designs comes with some inconveniences:
    - The delegator has to transfer the NFT to the registry, he loses direct ownership but can benefit from delegatees benefits and could at any moment transfer back its NFT because the registry would have set an approval for it.
    - All the NFTs are stored in the same registry (even that if code is kept simple, a e2e security is 99.9% assured).
    - Incompatibility for Soulbond NFTs, since my initial design doesn't support it.
    - Eligibility for airdrops is complicated, since all the NFTs are stored in the same registry (can be solved by new registry per NFT collection).
    - Delegatee benefits from 'push' interactions, but not from 'pull' interactions, since the NFT is not in its wallet.

Note: Last 2 drawbacks can be solved by flash loaning NFT to the registry on multicall operation and then returning it to the delegator.

### What I like about this design
· It's very minimalistic, follows KISS, and it's gas efficient.   
· Such an architecture is gas efficient for Account Abstraction wallets, acting as the delegatee they can interact with the NFT without direct ownership, and the delegator can revoke the delegation at any time.
· There's low overhead for registering since only the following two SSTORES would be needed:
    - Delegator to (NFT tokenId, NFT contract address) mapping.
    - Delegator to delegatee to bool mapping (multiple delegatees can be registered for the same NFT)

## What's next?

Will think about primitives that could improve this design and/or create even better designs:
    - Meta transactions
    - Wrapper NFTs, to ensure that weird/edge custom NFT implementations aren't vulnerable. This is related to the prior point, if we them in ERC721Permit implementations.
    - EIPs like ERC-6551, EIP-6066 and EIP-5058.
    - Consider what happens when Delegator is a contract
    - Consider what happens when Delegator transfers the NFT to another address, would result in mismatches in the registry.

Also would like to figure out how to solve the Soulbond NFTs problem.