gsutil -m cp -r gs://spls/gsp067/python-docs-samples .

cd python-docs-samples/appengine/standard_python3/hello_world

sed -i "s/python37/python39/g" app.yaml

gcloud app create --region=$REGION

yes | gcloud app deploy
