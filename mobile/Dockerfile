# Stage 1: Serve the app with Nginx
FROM nginx:alpine

# The build/web directory should be generated locally by running 'flutter build web'
COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
