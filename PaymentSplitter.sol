// SPDX-License-Identifier: GPL-3.0
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

pragma solidity ^0.8.0;
    /********************Begin of Payment Splitter *********************************/
    /**
     * @dev this section contains the methods used
     * to split payment between all collaborators of this project
     */
contract PaymentSplitter is Ownable{
    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    uint256 private _totalShares;
    uint256 private _totalReleased;

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;
    bool private initialized = false;

    // @dev attributes for collaborators and investors shares management
    uint256 private projectFees;
    mapping(address => uint256) private projectInvestments;
    address[] private projectInvestors;
    /**
     * @dev The Ether received will be logged with {PaymentReceived} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Ether.
     *
     * To learn more about this see the Solidity documentation for
     * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
     * functions].
     */
    receive() external payable virtual {
        emit PaymentReceived(msg.sender, msg.value);
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     */
    function totalReleased() public view returns (uint256) {
        return _totalReleased;
    }

    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }

    /**
     * @dev Getter for the amount of Ether already released to a payee.
     */
    function released(address account) public view returns (uint256) {
        return _released[account];
    }

    /**
     * @dev Getter for the address of the payee number `index`.
     */
    function payee(uint256 index) public view returns (address) {
        return _payees[index];
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function release(address payable account) public virtual {
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");
        require(msg.sender == account,"Not authorized");
        uint256 totalReceived = address(this).balance + _totalReleased;
        uint256 payment = (totalReceived * _shares[account]) /
            _totalShares -
            _released[account];

        require(payment != 0, "Account is not due payment");

        _released[account] = _released[account] + payment;
        _totalReleased = _totalReleased + payment;

        Address.sendValue(account, payment);
        // payable(account).send(payment);
        emit PaymentReleased(account, payment);
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param shares_ The number of shares owned by the payee.
     */
    function _addPayee(address account, uint256 shares_) internal {
        require(
            account != address(0),
            "Account is the zero address"
        );
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(
            _shares[account] == 0,
            "Account already has shares"
        );

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares = _totalShares + shares_;
        emit PayeeAdded(account, shares_);
    }

    /**
     * @dev Return all payees
     */
    function getPayees() public view returns (address[] memory) {
        return _payees;
    }
    
    /**
     * @dev Set up all holders shares
     * @param payees wallets of holders.
     * @param shares_ shares of each holder.
     */
    function initializePaymentSplitter(
        address[] memory payees,
        uint256[] memory shares_
    ) public onlyOwner {
        require(!initialized, "Payment Split Already Initialized!");
        require(
            payees.length == shares_.length,
            "Payees and shares length mismatch"
        );
        require(payees.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }
        initialized = true;
    }
    /*************** Begin of Collaborators and investors *******************************/
    /**
     * @dev Add invested fees in the project
     * @param investor wallet of investor.
     * @param fees share of each holder.
     */
    function addProjectFees(address investor, uint256 fees) public onlyOwner {
        projectInvestments[investor] = fees;
        projectInvestors.push(investor);
        projectFees += fees;
    }

    /**
     * @dev if money has been invested in this project, the investment will be reimbursed
     *      before splitting money between holders
     */
    function reimburseProjectFees() public onlyOwner {
        require(projectFees != 0, "There are no project fees.");
        require(address(this).balance != 0, "Balance is empty");
        require(
            address(this).balance >= projectFees,
            "Balance is not enough to reimburse project fees"
        );
        for (uint256 i = 0; i < projectInvestors.length; i++) {
            require(
                payable(projectInvestors[i]).send(
                    projectInvestments[projectInvestors[i]]
                )
            );
            projectFees -= projectInvestments[projectInvestors[i]];
            delete projectInvestments[projectInvestors[i]];
            delete projectInvestors[i];
        }
    }

    /*************** End of Collaborators and investors *******************************/
}
    /********************End of Payment Splitter *********************************/