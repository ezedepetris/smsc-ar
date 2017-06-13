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
    response = run('evalnumero', nil, number)
    response["data"]["estado"]
    
    # public function evalNumero($prefijo, $fijo = null)
    # {
    #   $ret = $this->exec('evalnumero', '&num='.$prefijo.($fijo === null?'':'-'.$fijo));
    #   if (!$ret)
    #     return false;
    #   if ($this->getStatusCode() != 200)
    #   {
    #      throw new Exception($this->getStatusMessage(), $this->getStatusCode());
    #      return false;
    #   } else {
    #     $ret = $this->getData();
    #     return $ret['estado'];
    #   }
    # }
  end

  def active?
    response = run('estado')
    response["code"] == 200
  end

  ##
   # Estado del sistema SMSC.
   # @return bool Devuelve true si no hay demoras en la entrega.
  #
  def status
    response = run('estado')
    { code: response["code"], message: response["message"] }
    # public function getEstado()
    # {
    #   $ret = $this->exec('estado');
    #   if (!$ret)
    #     return false;
    #   if ($this->getStatusCode() != 200)
    #   {
    #      throw new Exception($this->getStatusMessage(), $this->getStatusCode());
    #      return false;
    #   } else {
    #     $ret = $this->getData();
    #     return $ret['estado'];
    #   }
    # }
  end

  ##
  #
  # 
  #
  def balance
    response = run('saldo')
    response["data"]["mensajes"]

    # public function getSaldo()
    # {
    #   $ret = $this->exec('saldo');
    #   if (!$ret)
    #     return false;
    #   if ($this->getStatusCode() != 200)
    #   {
    #     throw new Exception($this->getStatusMessage(), $this->getStatusCode());
    #     return false;
    #   } else {
    #     $ret = $this->getData();
    #     return $ret['mensajes'];
    #   }
    # }
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
    response = run('encolados', nil, nil, nil, nil, priority)
    response["data"]["mensajes"]
    # public function getEncolados($prioridad = 0)
    # {
    #   $ret = $this->exec('encolados', '&prioridad='.intval($prioridad));
    #   if (!$ret)
    #     return false;
    #   if ($this->getStatusCode() != 200)
    #   {
    #     throw new Exception($this->getStatusMessage(), $this->getStatusCode());
    #     return false;
    #   } else {
    #     $ret = $this->getData();
    #     return $ret['mensajes'];
    #   }
    # }
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
    response = run('enviar', nil, num, msj, time)
    response["code"] == 200

    # public function enviar()
    # {
    #   $ret = $this->exec('enviar', '&num='.implode(',', $this->numeros).'&msj='.urlencode($this->mensaje));
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
  end

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

    JSON.parse open(query).read

    # public function exec($cmd = null, $extradata = null)
    # {
    #   $this->return = null;
    #   // construyo la URL de consulta
    #   $url = 'https://www.smsc.com.ar/api/0.2/?alias='.$this->alias.'&apikey='.$this->apikey;
    #   $url2 = '';
    #   if ($cmd !== null)
    #     $url2 .= '&cmd='.$cmd;
    #   if ($extradata !== null)
    #     $url2 .= $extradata;
    #   // hago la consulta
    #   $data = @file_get_contents($url.$url2);
    #   if ($data === false)
    #   {
    #     throw new Exception('No se pudo conectar al servidor.', 1);
    #     return false;
    #   }
    #   $ret = json_decode($data, true);
    #   if (!is_array($ret))
    #   {
    #     throw new Exception('Datos recibidos, pero no han podido ser reconocidos ("'.$data.'") (url2='.$url2.').', 2);
    #     return false;
    #   }
    #   $this->return = $ret;
    #   return true;
    # }
  end

  def error(code)
    case code
      when 400 
        @errors << "Parámetro sin especificar"
      when 401 
        @errors << "Acceso no autorizado"
      when 402 
        @errors << "Comando no reconocido."
      when 403 
        @errors << "Número incorrecto"
      when 404 
        @errors << "Debe especificar al menos un número válido"
      when 405 
        @errors << "No tienes mensajes en tu cuenta"
      when 406 
        @errors << "Has superado el límite de sms diarios"
      when 499 
        @errors << "Error desconocido"
      else
        @errors << "Server error"
    end
  end
end
