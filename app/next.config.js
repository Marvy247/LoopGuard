
/** @type {import('next').NextConfig} */
const nextConfig = {
    webpack: (config, { isServer }) => {
        config.module.rules.push({
            test: /node_modules\/@walletconnect\/ethereum-provider\/node_modules\/thread-stream\/test/,
            use: 'null-loader',
        });
        config.module.rules.push({
            test: /node_modules\/thread-stream\/test/,
            use: 'null-loader',
        });

        if (!isServer) {
            config.resolve.fallback = {
                ...config.resolve.fallback,
                net: false,
                tls: false,
            };
        }
        return config;
    },
};

module.exports = nextConfig;
