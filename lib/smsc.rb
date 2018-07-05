require 'open-uri'

class Smsc
  include ActiveModel::Model

  def initialize(account, apiKey)
    @alias = account
    @apiKey = apiKey
  end

  ##
  # Valid the phone number
  # Return true if is a valid phone number
  ##
  def valid_phone?(number)
    response = run('evalnumero', nil, number)
    begin
      response["data"]["estado"]
    rescue => e
      error(response["code"])
      false
    end
  end

  ##
  # Check the server status, return true if it's active, false in other case
  ##
  def active?
    response = run('estado')
    success = response["code"] == 200
    raise 'NoSuccessCode' if !success
    success
  rescue => e
    error(response["code"])
    false
  end

  ##
  # Check the server status
  # Return hash with the keys :code, :message
  # code: is the status of the server response, 200 its oky!
  # message: is the message if the query to the serve has problems
  ##
  def status
    response = run('estado')
    { code: response["code"], message: response["message"] }
  rescue => e
    error(response["code"])
    false
  end

  ##
  # Check the balanca on Smsc
  # return the value balance or false in case of error
  ##
  def balance
    response = run('saldo')
    response["data"]["mensajes"]
  rescue => e
    error(response["code"])
    false
  end

  ##
  # Cancel all messages enqueued
  ##
  def cancel_queue
    response = run('cancelqueue')
    success = response["code"] == 200
    raise 'NoSuccessCode' if !success
    success
  rescue => e
    error(response["code"])
    false
  end

  ##
  # Chek the messages enqueued to send later
  # by default the parameter is 0
  # param priority 0:all 1:low 2:middle 3:high
  # return an array with all messages enqueued with te priority specified
  ##
  def enqueued(priority=0)
    response = run('encolados', nil, nil, nil, nil, priority)
    response["data"]["mensajes"]
  rescue => e
    error(response["code"])
    false
  end

  ##
  # ###########################################
  # ########   Method to send a SMS   #########
  # ###########################################
  #
  ##
  # take 3 params, num, msj time
  # num: is the phone number with code area included by the fault the api of Sms
  #   require the phone number on format xxxx-xxxxxxxxx, but, if you have other
  #   format, you can check it with the method valid_phone?(phone_number)
  # msj: is a string with the message to send, a message has "180(CHECK)"
  #   characters, if you include more characters, so you're sending two messages
  # time: this by default is nil, in case you specified this parameter
  #   the message will be enqueue at the datetime specified
  #   with the format "YYYY-MM-DD HH:MM:SS"
  #   Return true if the message was sended, false in other case
  ##
  def send(num, msj, time=nil)
    response = run('enviar', nil, num, msj, time)
    success = response["code"] == 200
    raise 'NoSuccessCode' if !success
    success
  rescue => e
    error(response["code"])
    false
  end

  ##
  # ###############################################
  # ########  Methods for making queries   ########
  # ###############################################
  #
  ##
  # Return the lastest 30 messages received
  #
  # You can specified an URL on https://www.smsc.com.ar/usuario/api/ then the
  # App will make a get to the url specified, that means you receive a new
  # message
  #
  # you can add a paramater 'lastId' by default none, and you can check all
  # messages recevided from the id specified.
  ##
  def received(lastId=nil)
    response = run('recibidos', lastId)
    response["data"].map do |message|
      {
        id: message["id"],
        date: message["fechahora"],
        message: message["mensaje"],
        from: message["de"],
        phone: message["linea"]
      }
    end
  rescue => e
    error(response["code"])
    false
  end

  ##
  # Return the lastest 30 smsc messages sent
  #
  # you can add a paramater 'lastId' by default none, and you can check all
  # messages sent from the id specified.
  ##
  def sent(lastId=nil)
    response = run('enviados', lastId)
    response["data"].map do |message|
      {
        id: message["id"],
        date: message["fechahora"],
        message: message["mensaje"],
        recipients: message["destinatarios"].map do |recipient|
          {
            code_area: recipient["prefijo"],
            phone: recipient["fijo"],
            status: recipient["enviado"]["estado_desc"]
          }
        end
      }
    end
  rescue => e
    error(response["code"])
    false
  end

  def errors?
    errors.any?
  end

  private

  def run(cmd=nil, lastId=nil, num=nil, msj=nil, time=nil, priority=nil)
    query = "https://www.smsc.com.ar/api/0.3/?alias=#{@alias}&apikey=#{@apiKey}&cmd=#{cmd}"
    options = []
    if msj.present?
      options << "msj=#{msj}"
    end

    if num.present?
      options << "num=#{num}"
    end

    if lastId.present?
      options << "ultimoid=#{lastId}"
    end

    if priority.present?
      options << "prioridad=#{priority}"
    end

    if time.present?
      options << "time=#{time}"
    end
    query += "&#{options.join('&')}" if options.present?

    begin
      JSON.parse open(query).read
    rescue => e
      { code: 500 }
    end
  end

  def error(code)
    case code.to_i
      when 400
        errors.add(:base, "Parameter not specified")
      when 401
        errors.add(:base, "Unauthorized access")
      when 402
        errors.add(:base, "Unrecognized command")
      when 403
        errors.add(:base, "Wrong number")
      when 404
        errors.add(:base, "You must specify at least one valid number")
      when 405
        errors.add(:base, "You don't have balance in your account")
      when 406
        errors.add(:base, "You have exceeded the daily sms limit")
      when 499
        errors.add(:base, "Unknown error")
      else
        errors.add(:base, "Server error")
    end
  end
end
