import * as React from "react"
import { Link } from "gatsby"
import Layout from "../components/Layout"

const AnotherPage = () => {
  return (
    <Layout>
      <h1 className="display-4 text-center mb-4">
        Another page
      </h1>
      <div className="d-flex flex-row flex-wrap justify-content-center">
        <Link 
          to="/" 
          className="btn btn-primary m-3 p-3"
          style={{width: "200px"}}>
          To home page
        </Link>
        <button 
          type="button" 
          className="btn btn-secondary m-3 p-3 umami--click--trigger-another-event"
          style={{width: "200px"}}>
          Trigger another event
        </button>
      </div>
    </Layout>
  )
}

export default AnotherPage
