// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Decentralized Identity Verification System
 * @dev Self-sovereign identity platform with verifiable credentials
 * @author Your Name
 */
contract Project {
    
    // Structures
    struct Credential {
        address issuer;
        bytes32 credentialHash;
        uint256 issuedAt;
        uint256 expiresAt;
        bool isRevoked;
        string credentialType;
    }
    
    struct Issuer {
        string name;
        bool isActive;
        uint256 registeredAt;
    }
    
    // State Variables
    mapping(address => bool) public registeredUsers;
    mapping(address => Issuer) public issuers;
    mapping(address => mapping(bytes32 => Credential)) public credentials;
    mapping(address => bytes32[]) public userCredentialList;
    mapping(address => mapping(address => bool)) public accessPermissions;
    
    address public admin;
    
    // Events
    event UserRegistered(address indexed user, uint256 timestamp);
    event IssuerRegistered(address indexed issuer, string name);
    event CredentialIssued(address indexed user, bytes32 indexed credentialId, string credentialType);
    event CredentialRevoked(address indexed user, bytes32 indexed credentialId);
    event AccessGranted(address indexed user, address indexed verifier);
    event AccessRevoked(address indexed user, address indexed verifier);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }
    
    modifier onlyRegisteredUser() {
        require(registeredUsers[msg.sender], "User not registered");
        _;
    }
    
    modifier onlyActiveIssuer() {
        require(issuers[msg.sender].isActive, "Not active issuer");
        _;
    }
    
    constructor() {
        admin = msg.sender;
    }
    
    // Core Function 1: Issue Credential
    /**
     * @dev Issue a verifiable credential to a user
     * @param user Address of the credential holder
     * @param credentialHash Hash of the credential data (stored off-chain)
     * @param credentialType Type of credential (e.g., "Education", "Employment")
     * @param validityPeriod Duration in seconds for credential validity
     */
    function issueCredential(
        address user,
        bytes32 credentialHash,
        string memory credentialType,
        uint256 validityPeriod
    ) external onlyActiveIssuer {
        require(registeredUsers[user], "User not registered");
        require(credentialHash != bytes32(0), "Invalid credential hash");
        require(validityPeriod > 0, "Invalid validity period");
        
        bytes32 credentialId = keccak256(
            abi.encodePacked(user, msg.sender, credentialHash, block.timestamp)
        );
        
        require(credentials[user][credentialId].issuer == address(0), "Credential exists");
        
        credentials[user][credentialId] = Credential({
            issuer: msg.sender,
            credentialHash: credentialHash,
            issuedAt: block.timestamp,
            expiresAt: block.timestamp + validityPeriod,
            isRevoked: false,
            credentialType: credentialType
        });
        
        userCredentialList[user].push(credentialId);
        
        emit CredentialIssued(user, credentialId, credentialType);
    }
    
    // Core Function 2: Verify Credential
    /**
     * @dev Verify the authenticity and validity of a credential
     * @param user Address of the credential holder
     * @param credentialId Unique identifier of the credential
     * @return isValid Whether the credential is valid
     * @return issuer Address of the credential issuer
     * @return credentialType Type of the credential
     * @return expiresAt Expiration timestamp
     */
    function verifyCredential(address user, bytes32 credentialId)
        external
        view
        returns (
            bool isValid,
            address issuer,
            string memory credentialType,
            uint256 expiresAt
        )
    {
        require(accessPermissions[user][msg.sender], "Access denied");
        
        Credential memory cred = credentials[user][credentialId];
        
        isValid = cred.issuer != address(0) &&
                  !cred.isRevoked &&
                  block.timestamp < cred.expiresAt &&
                  issuers[cred.issuer].isActive;
        
        return (isValid, cred.issuer, cred.credentialType, cred.expiresAt);
    }
    
    // Core Function 3: Manage Access Permissions
    /**
     * @dev Grant or revoke access to verifiers for credential verification
     * @param verifier Address of the verifier
     * @param grantAccess True to grant access, false to revoke
     */
    function manageAccess(address verifier, bool grantAccess) 
        external 
        onlyRegisteredUser 
    {
        require(verifier != address(0), "Invalid verifier");
        
        accessPermissions[msg.sender][verifier] = grantAccess;
        
        if (grantAccess) {
            emit AccessGranted(msg.sender, verifier);
        } else {
            emit AccessRevoked(msg.sender, verifier);
        }
    }
    
    // Supporting Functions
    
    function registerUser() external {
        require(!registeredUsers[msg.sender], "Already registered");
        registeredUsers[msg.sender] = true;
        emit UserRegistered(msg.sender, block.timestamp);
    }
    
    function registerIssuer(address issuer, string memory name) 
        external 
        onlyAdmin 
    {
        require(issuer != address(0), "Invalid address");
        require(!issuers[issuer].isActive, "Already registered");
        
        issuers[issuer] = Issuer({
            name: name,
            isActive: true,
            registeredAt: block.timestamp
        });
        
        emit IssuerRegistered(issuer, name);
    }
    
    function revokeCredential(address user, bytes32 credentialId) 
        external 
        onlyActiveIssuer 
    {
        Credential storage cred = credentials[user][credentialId];
        require(cred.issuer == msg.sender, "Not credential issuer");
        require(!cred.isRevoked, "Already revoked");
        
        cred.isRevoked = true;
        emit CredentialRevoked(user, credentialId);
    }
    
    function getUserCredentials(address user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return userCredentialList[user];
    }
    
    function hasAccess(address user, address verifier) 
        external 
        view 
        returns (bool) 
    {
        return accessPermissions[user][verifier];
    }
}
