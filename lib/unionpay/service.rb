#encoding:utf-8
require 'open-uri'
require 'digest'
module UnionPay
  RESP_SUCCESS  = "00"   #返回成功
  QUERY_SUCCESS = "0"    #查询成功
  QUERY_FAIL    = "1"
  QUERY_WAIT    = "2"
  QUERY_INVALID = "3"
  module Service

    def self.front_pay(args)
      args['orderTime']              ||= Time.now.strftime('%Y%m%d%H%M%S')         #交易时间, YYYYmmhhddHHMMSS
      args['orderCurrency']          ||= UnionPay::CURRENCY_CNY                    #交易币种，CURRENCY_CNY=>人民币
      trans_type = args['transType']
      if [UnionPay::CONSUME, UnionPay::PRE_AUTH].include? trans_type
        @@api_url = UnionPay.front_pay_url
        args.merge!(UnionPay::Pay_params_empty).merge!(UnionPay::Pay_params)
        @@param_check = UnionPay::Pay_params_check
      else
        # 前台交易仅支持 消费 和 预授权
        raise("Bad trans_type for front_pay. Use back_pay instead")
      end
      self.service(args,UnionPay::FRONT_PAY)
    end

    def self.responce(args)
      cupReserved = (args['cupReserved'] ||= '')
      cupReserved = Rack::Utils.parse_nested_query cupReserved.gsub(/^{/,'').gsub(/}$/,'')
      if !args['signature'] || !args['signMethod']
        raise('No signature Or signMethod set in notify data!')
      end

      args.delete 'signMethod'
      if args.delete('signature') != self.sign(args)
        raise('Bad signature returned!')
      end
      args.merge! cupReserved
      args.delete 'cupReserved'
      args
    end

    def self.service(args, service_type)
      if args['commodityUrl']
        args['commodityUrl'] = URI::encode(args['commodityUrl'])
      end

      has_reserved = false
      UnionPay::Mer_params_reserved.each do |k|
        if args.has_key? k
          value = args.delete k
          (arr_reserved ||= []) << "#{k}=#{value}"
          has_reserved = true
        end
      end

      if has_reserved
        args['merReserved'] = arr_reserved.join('&')
      else
        args['merReserved'] ||= ''
      end

      @@param_check.each do |k|
        raise("KEY [#{k}] not set in params given") unless args.has_key? k
      end

      # signature
      args['signature']    = self.sign(args)
      args['signMethod']   = UnionPay::Sign_method
      @@args = args
      self
    end

    def self.sign(args)
      sign_str = args.sort.map do |k,v|
        "#{k}=#{v}&" unless UnionPay::Sign_ignore_params.include? k
      end.join
      Digest::MD5.hexdigest(sign_str + Digest::MD5.hexdigest(UnionPay.security_key))
    end

    def self.form options={}
      attrs = options.map{|k,v| "#{k}='#{v}'"}.join(' ')
      html = [
        "<form #{attrs} action='#{@@api_url}' method='post'>"
      ]
      @@args.each do |k,v|
        html << "<input type='hidden' name='#{k}' value='#{v}' />"
      end
      if block_given?
        html << yield
        html << "</form>"
      end
      html.join
    end
  end
end
