import * as React from "react"
import { withPrefix } from 'gatsby';
import { ReactNode } from 'react';
import { Helmet } from 'react-helmet';
import "./layout.css"

// styles
const pageStyles = {
    color: "#232129",
    padding: 15,
    fontFamily: "-apple-system, Roboto, sans-serif, serif",
}

type LayoutProps = {
  children: ReactNode;
};

export default function Layout({ children }: LayoutProps) {
    return (
        <main style={pageStyles}>
            <Helmet>
                <script 
                    async defer
                    src={withPrefix('umami.js')} 
                    data-host-url={process.env.DATA_HOST_URL}
                    data-website-id={process.env.DATA_WEBSITE_ID} 
                    type="text/javascript"/>
                <link 
                    href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" 
                    rel="stylesheet" 
                    integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" 
                    crossOrigin="anonymous" />
            </Helmet>
            <div className='container h-100'>
                <div className="d-flex flex-column align-content-center justify-content-center h-100">
                    {children}
                </div>
            </div>
            
        </main>
    )
}