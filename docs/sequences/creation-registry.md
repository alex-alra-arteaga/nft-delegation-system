sequenceDiagram
    participant Delegator as Delegator
    participant DR as Delegator Registry
    participant DA as Delegator Account

    Delegator->>DR: registerDelegator()
    Note over DR: Generates salt from delegator's address
    DR->>DA: Clone Deterministic (salt)
    Note over DA: Initializes with Delegator's address
    DA-->>DR: Account Initialized
    DR->>Delegator: Returns Account Address
    Note over DR: Maps Delegator to Account