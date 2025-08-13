from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.client import Client
from diagrams.onprem.network import Nginx
from diagrams.programming.language import Python
from diagrams.onprem.compute import Server
from diagrams.generic.storage import Storage
from diagrams.gcp.database import Firestore
from diagrams.gcp.storage import GCS

# Updated architecture without explicit endpoint nodes, Flutter App (Android only)

with Diagram("Fashion Reco Architecture (v2)", show=False, filename="arch_v2", direction="LR"):
    client = Client("Flutter App\n(Android)")

    with Cluster("Public / PaaS"):
        edge = Nginx("Nginx / Ingress")
        asgi = Server("Gunicorn +\nUvicorn (ASGI)")

    with Cluster("FastAPI Backend (Python)"):
        api = Python("FastAPI\n(Pydantic, VS Code)")
        with Cluster("Recommenders"):
            rules = Server("Rule-based\nSITUATION_STYLE_MAP\nEXCLUDE_KEYWORDS")
            sbert = Server("SBERT\n(SentenceTransformers)")
            pkl = Storage("Embeddings .pkl\n(by style/category)")

    with Cluster("Google Cloud"):
        db = Firestore("Firebase Firestore\nclothes/{style}/{category}\nusers/{email}/favorites")
        gcs = GCS("Cloud Storage\n(embeddings, images)")

    with Cluster("Data Pipeline (AI Dev)"):
        naver = Server("Naver Shopping API\n(수집)")
        preprocess = Server("전처리/검수\n(엑셀화, 품질관리)")
        embed = Server("임베딩 생성\nSBERT -> numpy")
        joblib_dump = Server("pkl 생성\n(joblib)")

    # Client -> Edge -> ASGI -> API
    client >> Edge(label="HTTPS") >> edge >> asgi >> api

    # API -> Recommenders
    api >> rules
    api >> sbert >> pkl

    # API -> GCP services
    api >> Edge(label="/favorites, /recommend") >> db
    api >> Edge(label="images / embeddings") >> gcs

    # Data pipeline flows
    naver >> Edge(label="raw items") >> preprocess
    preprocess >> Edge(label="metadata\n(title, image, link,\ncategory, season, style, gender)") >> db
    preprocess >> Edge(label="titles") >> embed >> Edge(label="vectors (numpy)") >> joblib_dump >> Edge(label="upload") >> gcs

    # Backend reads pkl/images from GCS as needed
    gcs >> Edge(label="download on startup / on demand") >> pkl
