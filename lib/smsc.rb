require 'open-uri'

class Smsc
  attr_reader :errors

  def initialize(account, apiKey)
    @alias = account
    @apiKey = apiKey
    @errors = []
  end

  ##
  # Validar número
  # @return bool Devuelve true si es un número válido.
  #
  def valid_phone?(number)
    begin
      response = run('evalnumero', nil, number)
      response["data"]["estado"]
    rescue => e
      errors(response["code"])
      false
    end
  end

  def active?
    begin
      response = run('estado')
      response["code"] == 200
    rescue => e
      errors(response["code"])
      false
    end
  end

  ##
   # Estado del sistema SMSC.
   # @return bool Devuelve true si no hay demoras en la entrega.
  #
  def status
    begin
      response = run('estado')
      { code: response["code"], message: response["message"] }
    rescue => e
      errors(response["code"])
      false
    end
  end

  ##
  #
  # 
  #
  def balance
    begin
      response = run('saldo')
      response["data"]["mensajes"]
    rescue => e
      errors(response["code"])
      false
    end
  end

  # Todos los SMS que están esperando para salir son marcados como cancelados. 
  # De esa forma la cola que en 0 y esos SMS nunca saldrán.
  def cancel_queue
    
  end

  ##
  #
  # @param int $prioridad 0:todos 1:baja 2:media 3:alta
  # @return array
  #
  def enqueued(priority=0)
    begin
      response = run('encolados', nil, nil, nil, nil, priority)
      response["data"]["mensajes"]
    rescue => e
      errors(response["code"])
      false
    end
  end

  ##
  # ###########################################
  # #######   Metodos para enviar SMS   #######
  # ###########################################
  #
  ##
  # @param integer $prefijo  Prefijo del área, sin 0
  #          Ej: 2627 ó 2627530000
  # @param integer $fijo Número luego del 15, sin 15
  #          Si sólo especifica prefijo, se tomará como número completo (no recomendado).
  #          Ej: 530000
  #
  def send(num, msj, time=nil)
    begin
      response = run('enviar', nil, num, msj, time)
      response["code"] == 200
    rescue => e
      errors(response["code"])
      false
    end
  end

  ##
  # ###############################################
  # #######  Metodos para hacer consultas   #######
  # ###############################################
  #
  ##
  # Devuelve los últimos 30 SMSC recibidos.
  # 
  # Lo óptimo es usar esta función cuando se recibe la notificación, que puede
  # especificar en https://www.smsc.com.ar/usuario/api/
  # 
  # @param int $ultimoid si se especifica, el sistema sólo devuelve los SMS
  #            más nuevos al sms con id especificado (acelera la
  #            consulta y permite un chequeo rápido de nuevos mensajes)
  #
  def received(lastId=nil)
    begin
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
      errors(response["code"])
      false
    end
  end
    # public function getRecibidos($ultimoid = 0)
    # {
    #   $ret = $this->exec('recibidos', '&ultimoid='.(int)$ultimoid);
    #   if (!$ret)
    #     return false;
    #   if ($this->getStatusCode() != 200)
    #   {
    #      throw new Exception($this->getStatusMessage(), $this->getStatusCode());
    #      return false;
    #   } else {
    #     return $this->getData();
    #   }
    # }

  # Return the lastest 30 smsc messages sent..
  # 
  # Lo óptimo es usar esta función cuando se recibe la notificación, que puede
  # especificar en https://www.smsc.com.ar/usuario/api/
  # 
  # @param int $ultimoid si se especifica, el sistema sólo devuelve los SMS
  #            más nuevos al sms con id especificado (acelera la
  #            consulta y permite un chequeo rápido de los mensajes enviados)
  #
  def sent(lastId=nil)
    begin
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
      errors(response["code"])
      false
    end
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
    case code
      when 400 
        "Parameter not specified"
      when 401 
        "Unauthorized access"
      when 402 
        "Unrecognized command"
      when 403 
        "Wrong number"
      when 404 
        "You must specify at least one valid number"
      when 405 
        "You have no messages in your account"
      when 406 
        "You have exceeded the daily sms limit"
      when 499 
        "Unknown error"
      else
        "Server error"
    end
  end
end
