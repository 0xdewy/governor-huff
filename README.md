# Governor-Huff

Checkpoint token rewritten in [Huff](https://github.com/huff-language/huff-rs). Original implementation: [Comp.sol](https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol)

## Development
Install the huff compiler 
```sh
curl -L get.huff.sh | bash
```

Install [foundry](https://github.com/foundry-rs/foundry) dependencies
```sh
forge install
```

Run tests:
```
forge test
```

Get bytecode
```
huffc src/ERC20Votes.huff --bytecode
```

## Performance
The huff implementation is currently about 15% cheaper, but can be further optimized.

## Security
This is experimental, unaudited code. 

## TODOs
- [ ] Implement delegateBySig()

- [ ] Checkpoint is manually packed into a single storage slot. Expose interface to return checkpoint as struct.

## Acknowledgement 
- ERC20Permit code adapted from: [devtooligan](https://github.com/devtooligan/huffhuffpass)

- Solidity implementation from:  [Compound](https://github.com/compound-finance/compound-protocol)
