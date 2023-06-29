use starknet::{ContractAddress};
use array::{Array};
use governance::timelock::{Call};

type ProposalId = felt252;

#[derive(Drop, Serde)]
struct Proposal {
    calls: Array<Call>, 
}

#[derive(Copy, Drop, Serde, storage_access::StorageAccess)]
struct VoteCounts {
    yay: u128,
    nay: u128
}

#[starknet::interface]
trait IGovernance<TStorage> {}

#[starknet::contract]
mod Governance {
    use super::{Proposal, VoteCounts, Array, IGovernance};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[external(v0)]
    impl GovernanceImpl of IGovernance<ContractState> {}
}
