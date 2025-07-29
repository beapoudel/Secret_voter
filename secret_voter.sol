// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    struct Candidate {
        uint256 id;
        string name;
        uint256 voteCount;
    }
    
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        bytes32 voteHash; // Hash of the vote for privacy
    }
    
    address public admin;
    string public electionName;
    bool public votingActive;
    
    mapping(address => Voter) public voters;
    mapping(uint256 => Candidate) public candidates;
    mapping(bytes32 => bool) public usedVoteHashes; // Prevent double voting with same hash
    
    uint256 public candidatesCount;
    uint256 public totalVotes;
    
    event VoterRegistered(address indexed voter);
    event VoteCast(address indexed voter, bytes32 voteHash);
    event ElectionStarted(string electionName);
    event ElectionEnded(string electionName);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "You are not a registered voter");
        _;
    }
    
    modifier votingIsActive() {
        require(votingActive, "Voting is not currently active");
        _;
    }
    
    constructor(string memory _electionName) {
        admin = msg.sender;
        electionName = _electionName;
        votingActive = false;
    }
    
    // Core Function 1: Register voters and manage election
    function registerVoter(address _voter) external onlyAdmin {
        require(!voters[_voter].isRegistered, "Voter already registered");
        
        voters[_voter] = Voter({
            isRegistered: true,
            hasVoted: false,
            voteHash: bytes32(0)
        });
        
        emit VoterRegistered(_voter);
    }
    
    function addCandidate(string memory _name) external onlyAdmin {
        require(!votingActive, "Cannot add candidates during active voting");
        
        candidatesCount++;
        candidates[candidatesCount] = Candidate({
            id: candidatesCount,
            name: _name,
            voteCount: 0
        });
    }
    
    function startVoting() external onlyAdmin {
        require(candidatesCount >= 2, "Need at least 2 candidates to start voting");
        votingActive = true;
        emit ElectionStarted(electionName);
    }
    
    function endVoting() external onlyAdmin {
        votingActive = false;
        emit ElectionEnded(electionName);
    }
    
    // Core Function 2: Cast secret vote using commitment scheme
    function castSecretVote(bytes32 _voteHash) external onlyRegisteredVoter votingIsActive {
        require(!voters[msg.sender].hasVoted, "You have already voted");
        require(!usedVoteHashes[_voteHash], "This vote hash has already been used");
        
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].voteHash = _voteHash;
        usedVoteHashes[_voteHash] = true;
        totalVotes++;
        
        emit VoteCast(msg.sender, _voteHash);
    }
    
    // Core Function 3: Reveal and count votes (simplified version)
    function revealVote(uint256 _candidateId, uint256 _nonce) external onlyRegisteredVoter {
        require(voters[msg.sender].hasVoted, "You haven't cast a vote yet");
        require(!votingActive, "Voting must be ended before revealing");
        require(_candidateId > 0 && _candidateId <= candidatesCount, "Invalid candidate ID");
        
        // Verify the vote hash matches the committed hash
        bytes32 computedHash = keccak256(abi.encodePacked(_candidateId, _nonce, msg.sender));
        require(computedHash == voters[msg.sender].voteHash, "Vote hash doesn't match");
        
        // Count the vote
        candidates[_candidateId].voteCount++;
        
        // Clear the vote hash to prevent re-revealing
        voters[msg.sender].voteHash = bytes32(0);
    }
    
    // Helper function to generate vote hash (for frontend use)
    function generateVoteHash(uint256 _candidateId, uint256 _nonce) external view returns (bytes32) {
        return keccak256(abi.encodePacked(_candidateId, _nonce, msg.sender));
    }
    
    // View functions
    function getCandidate(uint256 _candidateId) external view returns (string memory name, uint256 voteCount) {
        require(_candidateId > 0 && _candidateId <= candidatesCount, "Invalid candidate ID");
        Candidate memory candidate = candidates[_candidateId];
        return (candidate.name, candidate.voteCount);
    }
    
    function getWinner() external view returns (string memory winnerName, uint256 winnerVotes) {
        require(!votingActive, "Voting must be ended to determine winner");
        require(candidatesCount > 0, "No candidates available");
        
        uint256 winningVoteCount = 0;
        uint256 winnerId = 0;
        
        for (uint256 i = 1; i <= candidatesCount; i++) {
            if (candidates[i].voteCount > winningVoteCount) {
                winningVoteCount = candidates[i].voteCount;
                winnerId = i;
            }
        }
        
        return (candidates[winnerId].name, winningVoteCount);
    }
    
    function getElectionStatus() external view returns (
        string memory name,
        bool active,
        uint256 totalCandidates,
        uint256 totalVotesCast
    ) {
        return (electionName, votingActive, candidatesCount, totalVotes);
    }
}
