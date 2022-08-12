module.exports = async function (context, updateAciTrigger) {
    
    context.log('JavaScript Azure function running!');

    const axios = require('axios');

    try {
        context.log('JavaScript HTTP trigger function processed a request.');
        
        const updateAciUrl = process.env.UPDATE_ACI_URL;
        
        if(updateAciUrl === undefined) {
            throw new Error("Missing updateAciUrl.");
        }

        if(updateAciUrl === "") {
            context.log.warn("updateAciUrl is empty. The start request will not be sent.");
            return;
        }
    
        context.log(`Calling: ${updateAciUrl}&action=start`)
        await axios.get(`${updateAciUrl}&action=start`);
    }
    catch(err) {
        context.log.error(err);
    }
};
