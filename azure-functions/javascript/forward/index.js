module.exports = async function (context, req) {
  
  const { ServiceBusClient } = require("@azure/service-bus");
  const axios = require('axios');

  try {
    context.log('JavaScript HTTP trigger function processed a request.');
    
    const connectionString = process.env.SERVICE_BUS_CONNSTRING;
    const queueName = process.env.SERVICE_BUS_QUEUE_NAME;
    const umamiEndpoint = process.env.UMAMI_ENDPOINT;
    const apiEndpoint = process.env.API_ENDPOINT;
    const updateAciUrl = process.env.UPDATE_ACI_URL;
            
    if(connectionString === undefined) {
      throw new Error("Missing connectionString.");
    }
    
    if(queueName === undefined) {
      throw new Error("Missing queueName.");
    }
    
    if(umamiEndpoint === undefined) {
      throw new Error("Missing umami endpoint.");
    }

    if(apiEndpoint === undefined) {
      throw new Error("Missing api endpoint.");
    }

    if(updateAciUrl === undefined) {
      throw new Error("Missing function app url.");
    }

    if(updateAciUrl === "") {
      context.log.warn("updateAciUrl is empty. The stop request will not be sent.");
      return;
    }

    const sbClient = new ServiceBusClient(connectionString);

    const receiver = sbClient.createReceiver(queueName, options = { receiveMode: "receiveAndDelete"} );

    let counter = 0;
    
    while(true) {
      
      const messages = await receiver.receiveMessages(1, options = { maxWaitTimeInMs: 1500});

      if(messages.length === 0) {
        if(updateAciUrl != "") {
          context.log(`${updateAciUrl}&action=stop`) 
          axios.get(`${updateAciUrl}&action=stop`)
        }
        break;
      }

      const message = messages[0];

      let axiosOptions = { 
        headers: { 
          "accept": message.body.headers["accept"] ?? "*/*",
          "accept-language": message.body.headers["accept-language"] ?? "en-US,en;q=0.9",
          "cache-control":"no-cache",
          "content-type": message.body.headers["content-type"] ?? "application/json",
          "pragma": "no-cache",
          "user-agent": message.body.headers["user-agent"] ?? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36",
          ...(message.body.headers["referer"]) && {"referer": message.body.headers["referer"]},
          ...(message.body.headers["custom-client-ip"]) && {"custom-client-ip": message.body.headers["custom-client-ip"]},
        }
      };

      if(axiosOptions.headers["custom-client-ip"] && axiosOptions.headers["custom-client-ip"].includes(",")) {
        axiosOptions.headers["custom-client-ip"] = axiosOptions.headers["custom-client-ip"].split(',').shift();
      }

      // For debug purpose
      if(process.env.PRINT_DATA) {
        context.log(axiosOptions);
        context.log(message.body.data);
      }
      
      const response = await axios.post(
        `${umamiEndpoint}/api/collect`, 
        message.body.data, 
        axiosOptions
      );
      
      context.log(`${counter}: ${response.status}`);
      counter++;

      if(counter > 50) {
        context.log(`Calling: ${apiEndpoint}/api/forward`)
        axios.get(`${apiEndpoint}/api/forward`);
        break;
      }
    }
    
    await receiver.close();	
    await sbClient.close();

    context.res = {
      status: 200,
      body: {
        success: true,
        messsage: 'OK'
      }
    };
  }
  catch(err) {
    context.log.error(err);
    if(updateAciUrl != "") {
      context.log.error(`${updateAciUrl}&action=stop`)
      axios.get(`${updateAciUrl}&action=stop`)
    }
    context.res = {
      status: 500,
      body: {
        success: false,
        messsage: 'An error occured while processing the request.',
        details: err
      }
    };
  }
}
