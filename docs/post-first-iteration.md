# Post first iteration thought process

- Just finished the first iteration of the design, and I'm happy with the results.
- The design is minimalistic, follows KISS, which makes it easy to debug and audit, and it's gas efficient.


## Conclusions

- I have to yet validate the design and the trade-offs that I've made.
- It is possible that I have missed some edge cases, or that I have made some wrong assumptions but it's a good start.
- Will give

### What's next?
- Will add support for ERC20, ERC1155.
- Will create time-locked delegations.
- Will create a wrapper NFT to ensure that weird/edge custom NFT implementations aren't vulnerable or impractical, like Soulbound NFTs.
- This last point can also a nice to have, even for delegatees to get a Liquid NFT, but it's not a priority at the moment.
- Will think if a compatibility with EIPs like ERC-6551, EIP-6066 and EIP-5058 is possible and/or desirable.
- Add event logging.