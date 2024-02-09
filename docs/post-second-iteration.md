# Post second iteration thought process

- Found a very interesting vulnerability, which consisted on calling the contracts `delegate` and `revoke` functions when the NFT is in the registry when doing the multicall, being possible to delegate the NFT to another address, or to revoke the delegation, without the delegator's consent.
- A naive solution would be to prevent the multicall targets to be the registry, but the malicious contract could just transfer the NFT to itself and manipulate state from `delegate` and `revoke` functions.
- The correct solution is having reentrancy guards in this functions

- Another vulnerability found was that, since there would be lots of different approvals from different nftContracts from different users, it is not enough to just check if the target is the nftContract that is being flash loaned, but there sould be a mapping to check if such a target is a registered NFT contract, and if it is, restrict the call.
- But this would be another naive solution, since it would open a DDOS vector, where a malicious attacker could just register lots of important contracts, like Uniswaps `NonFungiblePositionManager`, and prevent the multicall from interacting with it, since it inherits and ERC721 implementation.
- The correct solution is to deploy a new contract for every registered delegator, so that there is no central contract with all the approvals set, but a contract for each delegator, with only its own approvals, and a multicall per delegator.
- For that, I will use MinimalProxy, which is a contract factory that deploys a new contract with the same bytecode as the target contract, and then initializes it with the desired state.
- It uses to be 99% cheaper than deploying a new contract with convential manners, but involves a ~2500 gas overhead (100 for delegatecall and ~2100 for sload from cold slot where implementation is stored). If the contract deployment size resulsts not being that big we can use a create2 deployment process.

- Found out that I'll need a new approve to be done once the NFT is returned at the end of the multicall, since any `_transfer` clears the approvals.
- An `approvalForAll` would fix this issue, but coming with the trade-off of having to approve the registry for all the NFTs, which is riskier, but it is a practice widely adopted by NFT marketplaces.

- Since a vector attack is to call the nft contract in the multicall to approve yourself the NFT, I intended to prevent the multicall to call any registered NFT contract, but this restricts interactions with certain NFTs, like Uniswap's `NonFungiblePositionManager`, which is an ERC721 implementation.
- I will use a permissions approach:
    - The NONE permission will have a target restriction for any registered NFT contract,.
    - The FULL permission will have no target restrictions, this is intended to be used for delegatee that are trusted.

## Conclusions

- The design looks functional for NFTs.
- 
- Will go by now with the `setApprovalForAll` approach, since will be compatible with any Registry user, instead Openfort decides to use this delegation system internally for its Account Abstraction Wallets, I will use it.
- I've undertook a small trade-off to code selfexplainingness for more gas efficiency, by having the 'isDelegated' mapping removed by the `delegateeExpiration`, which merges the delegation time expiration and the delegation existence check in one single SSTORE.
- The alternative would be having a struct with a bool and a uint248, which would just a little bit more expensive due to 2 SSTORES, 1 cold (1000 gas) and 1 warm (100 gas), since both variable are packed inside the same bytes32 slot.

## What's next?

- Before implementing the ERC20 and ERC1155, I will do challenge my assumptions, do a quick security audit and unit test the current implementation.
- For that I will use the Branching Tree Technique, which consists on creating a tree of possible states and transitions, and then testing all the possible transitions, to make sure that the state is consistent and that the transitions are safe.
- Such a practice enforces the dev to think about all the possible states and transitions, and with the use of nested function modifiers, it gives the code a visual representation of the state machine, testing and selfdocumenting the code at the same time.
- I will also fork test mainnet to test the code with real NFT implementations, priorizing the most popular ones, with ranging standards like ERC721A, ERC721C..., while interacting with the most relevant NFT interactions, like collecting liquidity fees, interacting with Seaport...