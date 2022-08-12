module.exports = async function (context, forwardTrigger) {
    
    context.log('JavaScript Azure function running!');
    
    const axios = require('axios');

    try {
        context.log('JavaScript HTTP trigger function processed a request.');
        
        const apiEndpoint = process.env.API_ENDPOINT;

        context.log(`apiEndpoint: ${apiEndpoint}`)
        
        if(apiEndpoint === undefined) {
            throw new Error("Missing apiEndpoint.")
        }
        
        context.log(`Calling: ${apiEndpoint}/api/forward`)

        const response = axios.get(`${apiEndpoint}/api/forward`)
        
        context.log(response.status);
    }
    catch(err) {
        context.log.error(err);
    }
};
