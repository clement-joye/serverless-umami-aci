module.exports = async function (context, req) {
  
  const { ServiceBusClient } = require("@azure/service-bus");

  try {

    context.log('JavaScript HTTP trigger function processed a request.');
  
    var ip = req.headers['x-forwarded-for'];

    if(process.env.CLIENT_IP_HEADER) {
      req.headers[process.env.CLIENT_IP_HEADER] = ip;
    }

    const connectionString = process.env.SERVICE_BUS_CONNSTRING;
    const queueName = process.env.SERVICE_BUS_QUEUE_NAME;

    if(connectionString === undefined) {
      throw new Error("Missing connectionString.");
    }
    
    if(queueName === undefined) {
      throw new Error("Missing queueName.");
    }

    let check = JSON.stringify(req);

    if(check.length > 10000) {
      throw new Error("Request too big.");
    }

    if(req.headers.length > 30) {
      throw new Error("Too many headers.");
    }

    if(req.body.length > 1000) {
      throw new Error("Body too long.");
    }

    const sbClient = new ServiceBusClient(connectionString);
	  const sender = sbClient.createSender(queueName);

    const message= {
      body: { 
        data: req.body,
        headers: req.headers,
        url: req.url,
        method: req.method
      }
    };
    
    // Set a timestamp for the event / pageview here. 
    message.body.data.payload["created_at"] = new Date().toISOString()

    console.log(`Sending message:`)
    console.log(message)
    
    await sender.sendMessages(message)
  }
  catch(err) {
    console.log(err);
    context.res = {
      status: 500,
      body: {
        success: false,
        messsage: 'An error occured while processing the request.'
      }
    };
  }
}
