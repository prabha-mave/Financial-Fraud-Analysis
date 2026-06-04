-- 1. Accounts
create table accounts(
	account_id text,
	customer_id text,
	account_type_id text,
	account_status_id text,
	balance decimal(15,2),
	opening_date date
);

-- 2. Account Statuses
create table account_statuses(
	account_status_id text,
	status_name text
);

-- 3. Account Types
create table account_types(
	account_type_id text,
	type_name text
);

-- 4. Addresses
create table addresses(
	address_id text,
	street varchar(50),
	city varchar(50),
	country varchar(25)
);

-- 5. Branches
create table branches(
	branch_id text,
	branch_name varchar(25),
	address_id text
);

-- 6. Customers
create table customers(
	customer_id text,
	first_name varchar(50),
	last_name varchar(40),
	date_of_birth date,
	address_id text,
	customer_type_id text
);

-- 7. Customer Types
create table customer_types(
	customer_type_id text,
	type_name text
);

-- 8. Loans
create table loans(
	loan_id text,
	account_id text,
	loan_status_id text,
	principal_amount decimal(15,2),
	interest_rate decimal(5,4),
	start_date date,
	estimated_end_date date
);

-- 9. Loan Statuses
create table loan_statuses(
	loan_status_id text,
	status_name text
);

-- 10. Transactions
create table transactions(
	transaction_id text,
	account_origin_id text,
	account_destination_id text,
	transaction_type_id text,
	amount decimal(15,2),
	transaction_date_time timestamp,
	transaction_date date,
	transaction_time time,
	branch_id text
);

-- 11. Transaction Types
create table transaction_types(
	transaction_type_id text,
	type_name text
);


-----------------------------------------------------------


--Query 1. High-Velocity Transactions (Same Account, Short Window)
--Find accounts that initiated multiple transactions within 5 minutes of each other.
create view high_velocity_transactions as

with txn_time as(
	select
		transaction_id,
		account_origin_id,
		transaction_date_time,
		lag(transaction_date_time) over(
		partition by (account_origin_id)
		order by(transaction_date_time)
		)as previous_txn_time
	from transactions
)
select 
	transaction_id,
	account_origin_id,
	transaction_date_time,
	previous_txn_time,
	(transaction_date_time - previous_txn_time) as time_difference
from txn_time
where previous_txn_time is not null
and transaction_date_time < previous_txn_time + interval '5 minutes';


-----------------------------------------------------------


-- Query 2. Spiking Transaction Values (Comparing to Account Balance)
-- Business Logic: Flag transactions where a single withdrawal or transfer 
--takes out more than 70% of the account’s total closing balance.
create view spiking_transaction_values as

select 
	t.transaction_id,
	a.balance as account_balance,
	t.amount as transaction_amount,
	round((t.amount/a.balance)*100,2) as withdrawal_amount

from accounts a
join transactions t on a.account_id = t.account_origin_id
join transaction_types tt on t.transaction_type_id = tt.transaction_type_id
where tt.type_name in ('Withdrawal', 'Transfer')
and a.balance > 0
and t.amount > (0.70*a.balance);


-----------------------------------------------------------


-- Query 3: Rapid Funds Drain (Ping-Pong Money Movement)
--Business Logic: Catch instances where an account receives a large destination deposit 
--and instantly transfers it out to another account within the same day.
create view rapid_funds_drain as

select
	t2.transaction_id,
	t1.account_destination_id as middle_account,
	t1.amount as amount_received,
	t2.account_destination_id as destination_account,
	t2.amount as amount_sent,
	t1.transaction_date
from transactions t1
join transactions t2 on t1.account_destination_id = t2.account_origin_id
where t2.transaction_date_time > t1.transaction_date_time
	and t2.transaction_date = t1.transaction_date
	and t2.amount >= (t1.amount*0.95);


-----------------------------------------------------------


-- Query 4: Spiking Transaction Value Outliers
-- Business Logic: Flag transactions that are 3x higher than the user’s
-- moving average of their last 10 transactions.
create view transaction_outliers as 

with txn as(
		select 
			account_origin_id,
			transaction_id,
			amount,
			round(avg(amount) over (
				partition by account_origin_id
				order by transaction_time
				rows between 10 preceding and 1 preceding
			),2)as moving_avg_last_10
		from transactions
)
select *
from txn
where moving_avg_last_10 is not null
and amount > (3*moving_avg_last_10);


-----------------------------------------------------------


-- Query 5: Tracking Structural Structuring Operations (Smurfing Thresholds)
-- Business Logic: Find accounts grouping transactions that total just below the standard 
-- regulatory reporting notification cap of ₹10,000 over a rolling 48-hour period.
create view smurfing_transactions as

with txn as(
		select
			account_origin_id,
			transaction_id,
			amount,
			sum(amount) over(
				partition by account_origin_id
				order by transaction_date_time
				range between '48 hours' preceding and current row
			) as moving_sum_amount
		from transactions t
		join transaction_types tt on t.transaction_type_id = tt.transaction_type_id
		where tt.type_name = 'Deposit'
)
select *
from txn
where moving_sum_amount is not null
and moving_sum_amount between 10000 and 15000;
