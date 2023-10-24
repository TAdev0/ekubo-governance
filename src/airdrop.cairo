use starknet::ContractAddress;
use array::{Array};

#[derive(Copy, Drop, Serde, Hash)]
struct Claim {
    claimee: ContractAddress,
    amount: u128,
}

// The only method required by Airdrop is transfer, so we use a simplified interface
#[starknet::interface]
trait ITransferrableERC20<TStorage> {
    fn transfer(ref self: TStorage, recipient: ContractAddress, amount: u256);
}

#[starknet::interface]
trait IAirdrop<TStorage> {
    fn claim(ref self: TStorage, claim: Claim, proof: Array::<felt252>);
}

#[starknet::contract]
mod Airdrop {
    use super::{
        IAirdrop, ContractAddress, Claim, ITransferrableERC20Dispatcher,
        ITransferrableERC20DispatcherTrait
    };
    use hash::{LegacyHash};
    use array::{ArrayTrait, SpanTrait};
    use traits::{Into, TryInto};
    use starknet::{ContractAddressIntoFelt252};

    fn lt<X, +Copy<X>, +Into<X, u256>>(lhs: @X, rhs: @X) -> bool {
        let a: u256 = (*lhs).into();
        let b: u256 = (*rhs).into();
        return a < b;
    }

    // Compute the pedersen root of a merkle tree by combining the current node with each sibling up the tree
    fn compute_pedersen_root(current: felt252, mut proof: Span<felt252>) -> felt252 {
        match proof.pop_front() {
            Option::Some(proof_element) => {
                compute_pedersen_root(
                    if lt(@current, proof_element) {
                        pedersen::pedersen(current, *proof_element)
                    } else {
                        pedersen::pedersen(*proof_element, current)
                    },
                    proof
                )
            },
            Option::None(()) => { current },
        }
    }

    #[storage]
    struct Storage {
        root: felt252,
        token: ITransferrableERC20Dispatcher,
        claimed: LegacyMap<felt252, bool>,
    }

    #[derive(Drop, starknet::Event)]
    struct Claimed {
        claim: Claim
    }

    #[derive(starknet::Event, Drop)]
    #[event]
    enum Event {
        Claimed: Claimed,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token: ContractAddress, root: felt252) {
        self.root.write(root);
        self.token.write(ITransferrableERC20Dispatcher { contract_address: token });
    }

    #[external(v0)]
    impl AirdropImpl of IAirdrop<ContractState> {
        fn claim(ref self: ContractState, claim: Claim, proof: Array::<felt252>) {
            let leaf = LegacyHash::hash(0, claim);

            assert(!self.claimed.read(leaf), 'ALREADY_CLAIMED');
            assert(self.root.read() == compute_pedersen_root(leaf, proof.span()), 'INVALID_PROOF');
            self.claimed.write(leaf, true);

            self.token.read().transfer(claim.claimee, u256 { high: 0, low: claim.amount });

            self.emit(Claimed { claim });
        }
    }
}
