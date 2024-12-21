//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTCollateralLoan {
    // Struct to represent a loan
    struct Loan {
        address borrower;
        uint256 loanAmount;
        uint256 interestRate; // in percentage (e.g., 5 for 5%)
        uint256 dueDate; // Timestamp of loan repayment deadline
        address nftAddress;
        uint256 nftTokenId;
        bool isRepaid;
    }

    // State variables
    mapping(uint256 => Loan) public loans;
    uint256 public loanCounter;
    address public owner;

    // Events
    event LoanCreated(
        uint256 loanId,
        address borrower,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 dueDate,
        address nftAddress,
        uint256 nftTokenId
    );
    event LoanRepaid(uint256 loanId);
    event LoanDefaulted(uint256 loanId, address lender);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    // Function to create a loan with NFT collateral
    function createLoan(
        address _nftAddress,
        uint256 _nftTokenId,
        uint256 _loanAmount,
        uint256 _interestRate,
        uint256 _dueDate
    ) external {
        // Transfer NFT to contract as collateral
        IERC721(_nftAddress).transferFrom(msg.sender, address(this), _nftTokenId);

        // Create a loan record
        loans[loanCounter] = Loan({
            borrower: msg.sender,
            loanAmount: _loanAmount,
            interestRate: _interestRate,
            dueDate: _dueDate,
            nftAddress: _nftAddress,
            nftTokenId: _nftTokenId,
            isRepaid: false
        });

        emit LoanCreated(
            loanCounter,
            msg.sender,
            _loanAmount,
            _interestRate,
            _dueDate,
            _nftAddress,
            _nftTokenId
        );

        loanCounter++;
    }

    // Function to repay a loan
    function repayLoan(uint256 _loanId) external payable {
        Loan storage loan = loans[_loanId];

        require(msg.sender == loan.borrower, "Only the borrower can repay the loan");
        require(!loan.isRepaid, "Loan already repaid");
        require(block.timestamp <= loan.dueDate, "Loan repayment deadline has passed");

        // Calculate total repayment amount (principal + interest)
        uint256 repaymentAmount = loan.loanAmount + (loan.loanAmount * loan.interestRate) / 100;
        require(msg.value >= repaymentAmount, "Insufficient repayment amount");

        // Mark the loan as repaid
        loan.isRepaid = true;

        // Transfer the NFT back to the borrower
        IERC721(loan.nftAddress).transferFrom(address(this), loan.borrower, loan.nftTokenId);

        emit LoanRepaid(_loanId);
    }

    // Function to handle defaults
    function claimDefaultedNFT(uint256 _loanId) external onlyOwner {
        Loan storage loan = loans[_loanId];

        require(!loan.isRepaid, "Loan already repaid");
        require(block.timestamp > loan.dueDate, "Loan repayment deadline has not passed");

        // Transfer the NFT to the contract owner (lender)
        IERC721(loan.nftAddress).transferFrom(address(this), owner, loan.nftTokenId);

        emit LoanDefaulted(_loanId, owner);}
}