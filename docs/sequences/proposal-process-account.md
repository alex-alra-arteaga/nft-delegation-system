sequenceDiagram
    participant Delegatee as Delegatee
    participant DA as Delegator Account
    participant Delegator as Delegator

    Delegatee->>DA: proposeCalldataExecution(targets, data, value, info, continueOnFailure)
    Note over DA: Verifies Delegatee permission & NFT delegation
    DA-->>Delegatee: ProposalStatus.PENDING
    Note over DA: Proposal pending for Delegator's review

    Delegator->>DA: setProposalStatus(proposalHash, status)
    alt status == APPROVED
        DA-->>Delegator: ProposalStatus.APPROVED
    else status == REJECTED
        DA-->>Delegator: ProposalStatus.REJECTED
    end
    Note over DA: Updates proposal status

    alt ProposalStatus.APPROVED
        Delegatee->>DA: executeProposal(targets, data, value, info, continueOnFailure)
        Note over DA: Verifies proposal approval
        DA-->>Delegatee: Execution results
        Note over DA: Executes approved proposal actions
    else ProposalStatus != APPROVED
        DA-->>Delegatee: Execution denied
        Note over DA: Proposal not approved or executed
    end
