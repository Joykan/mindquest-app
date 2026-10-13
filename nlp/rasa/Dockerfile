# The MindQuest Rasa NLU server, for hosting it online (for example as a free
# Hugging Face Space, or on any server with Docker) instead of on the PC.
#
# The model is trained while the image is built, from config.yml and data/,
# so no model file has to be uploaded. Build context: this folder (nlp/rasa).
#
# The chat Edge Function calls POST /model/parse?token=... ; set RASA_TOKEN
# to the same value as the RASA_TOKEN secret in Supabase.

FROM rasa/rasa:3.6.21

WORKDIR /app
COPY --chown=1001:0 config.yml ./config.yml
COPY --chown=1001:0 data ./data

# NLU only (the replies come from the Edge Function).
RUN rasa train nlu --out models --fixed-model-name mindquest

# Some hosts (e.g. Hugging Face) run the container as a different user, so
# the folder must be writable by anyone; no usage statistics are sent.
USER root
RUN chmod -R a+rwX /app
USER 1001
ENV HOME=/app RASA_TELEMETRY_ENABLED=false

# Hugging Face Spaces send traffic to port 7860; other hosts can set PORT.
ENV PORT=7860
EXPOSE 7860

ENTRYPOINT []
CMD ["sh", "-c", "rasa run --enable-api --auth-token \"$RASA_TOKEN\" --model models --port \"$PORT\""]
