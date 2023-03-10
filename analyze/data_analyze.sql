-- 1）总锁仓金额
select sum(amount)
from (select totalvalidatorbalance / 1e9 as amount
      from epochs
      where epoch = (select max(epoch) from epochs)
      union
      select sum(ed.amount) / 1e9
      from eth1_deposits as ed
               left join validators as v on encode(ed.publickey, 'hex') = v.pubkeyhex
      where (v.pubkeyhex is null and ed.valid_signature is true)                              -- 在validator中不存在
         or (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs)) --在validator中存在但还未激活
      union
      select sum(balance) / 1e9
      from validators
      where pubkeyhex is not null
        and exitepoch <= (select max(epoch) from epochs)
        and (select max(epoch) from epochs) < withdrawableepoch --已退出，但是还没到账的
      union
      select sum(balance) / 1e9
      from validators
      where pubkeyhex is not null
        and exitepoch <= (select max(epoch) from epochs)
        and (select max(epoch) from epochs) >= withdrawableepoch --已完成退出，但未配置提款地址
        and substring(encode(withdrawalcredentials, 'hex'), 1, 2) = '00') as t

-- 2) 活跃的Validators
select count(*)
from validators
where activationepoch <= (select max(epoch) from epochs)
  and (select max(epoch) from epochs) < exitepoch

-- 3) deposited和pending的Validators
select distinct validatorindex, encode(ed.publickey, 'hex')
from eth1_deposits as ed
         left join validators as v on encode(ed.publickey, 'hex') = v.pubkeyhex
where (v.pubkeyhex is null and ed.valid_signature is true) -- 在validator中不存在
   or (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs))
--在validator中存在但还未激活


-- 4）已经申请退出等待Withdraw提款的所有validator的数量和金额（自愿和强制的都有）
select count(*), sum(balance)
from validators
where exitepoch != 9223372036854775807
and (
	(select max(epoch) from epochs) < exitepoch  --已申请，还未到 exitepoch
	or
	((select max(epoch) from epochs) >= exitepoch and (select max(epoch) from epochs) <  withdrawableepoch ) --到达exitepoch，但还没拿到钱
	or
	((select max(epoch) from epochs) > withdrawableepoch and substring(encode(withdrawalcredentials,  'hex'),1,2) = '00' ))
-- 应该可以拿到钱了，但是没配置提现地址

-- 4.1）自愿退出，没有数据，看不出来


-- 5）BLSChange 的 validators 数量和占比(正在验证中并配置了提现地址)
select round(sum(case when substring(encode(withdrawalcredentials, 'hex'), 1, 2) != '00' then 1 else 0 end) * 1.0 /
             count(*), 4)
from validators
where activationepoch <= (select max(epoch) from epochs)
  and (select max(epoch) from epochs) < exitepoch

-- 6）每日抵押的以太坊数量()
select sum(ed.amount) / 1e9
from eth1_deposits as ed
         left join validators as v on encode(ed.publickey, 'hex') = v.pubkeyhex
where (v.pubkeyhex is null and ed.valid_signature is true and block_numer > $昨日最大区块号) -- 在validator中不存在
   or (v.pubkeyhex is not null and v.activationepoch > (select max(epoch) from epochs) and
       validatorindex > $昨日最大validatorindex)
--在validator中存在但还未激活


-- 7）每日Withdraw的数量（根据slot可以计算出时间，从而可以查询每日体现数量）
select block_slot, sum(amount) / 1e9
from blocks_withdrawals
where validatorindex in (select validatorindex
                         from validators
                         where substring(encode(withdrawalcredentials, 'hex'), 1, 2) != '00'
    )
group by block_slot



