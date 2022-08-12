import * as React from "react"
import { Link } from "gatsby"
import Layout from "../components/Layout"

const IndexPage = () => {
  return (
    <Layout>
      <h1 className="display-4 text-center mb-4">
        Serverless analytics demo
      </h1>
      <div className="d-flex flex-row flex-wrap justify-content-center">
        <Link 
          to="/another-page" 
          className="btn btn-primary m-3 p-3"
          style={{width: "200px"}}>
          To another page
        </Link>
        <button 
          type="button" 
          className="btn btn-secondary m-3 p-3 umami--click--trigger-event"
          style={{width: "200px"}}>
          Trigger event
        </button>
      </div>
    </Layout>
  )
}

export default IndexPage
