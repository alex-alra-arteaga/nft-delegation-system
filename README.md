## Deployment Addresses on ¿Testnet?

## Documentation

## Usage

### Installation

### Build

### Test

### Deploy & Verirification

```shell
$ forge script script/DeployGenesisSC.s.sol:DeployGenesis --broadcast --rpc-url <your_rpc_url> --private-key <your_private_key> --verifier-url https://api.polygonscan.com/api --etherscan-api-key <your_polygonscan_api_key> --verify --legacy
```

Important to note that the most secure way is to deploy with the `--ledger` or `--trezor` flag instead of `--private-key`, for more information check the [documentation](https://book.getfoundry.sh/tutorials/best-practices?highlight=script%20best#private-key-management).

### Gas Snapshots

Written to `.gas.snapshot` file.

```shell
$ forge snapshot
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
