# draw_architecture.py
from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.client import Client
from diagrams.onprem.network import Nginx
from diagrams.programming.language import Python
from diagrams.onprem.compute import Server
from diagrams.generic.storage import Storage
from diagrams.gcp.database import Firestore
from diagrams.gcp.storage import GCS

with Diagram("Fashion Reco Architecture", show=False, filename="arch", direction="LR"):
    client = Client("Flutter App")

    with Cluster("Public / PaaS"):
        edge = Nginx("Nginx/Ingress")
        asgi = Server("Gunicorn + Uvicorn")

    with Cluster("FastAPI Backend (Python)"):
        api = Python("FastAPI")
        with Cluster("Recommenders"):
            rules = Server("Rule-based\n(SITUATION_STYLE_MAP,\nEXCLUDE_KEYWORDS)")
            sbert = Server("SBERT\n(SentenceTransformers)")
            pkl = Storage(".pkl Embeddings")

    with Cluster("Google Cloud"):
        db = Firestore("Firebase Firestore")
        gcs = GCS("Cloud Storage (opt)")

    client >> Edge(label="HTTPS") >> edge >> asgi >> api
    api >> rules
    api >> sbert >> pkl
    api >> Edge(label="/favorites, /recommend") >> db
    api >> Edge(label="images/embeddings") >> gcs
