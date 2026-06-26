import swaggerJsdoc from "swagger-jsdoc";
const options = {
    definition: {
        openapi: "3.0.0",
        info: {
            title: "Jasaku API",
            version: "1.0.0",
            description: "API Documentation Jasaku",
        },
        components: {
            securitySchemes: {
                bearerAuth: {
                    type: 'http',
                    scheme: 'bearer',
                    bearerFormat: 'JWT',
                },
            },
        },
        servers: [
            {
                url: "http://localhost:3000",
            },
        ],
    },
    apis: ["./src/docs/**/*.ts"],
};
const swaggerSpec = swaggerJsdoc(options);
export default swaggerSpec;
