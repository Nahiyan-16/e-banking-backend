import express from "express";
import cors from "cors";
import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from "@aws-sdk/client-s3";
import { STSClient, GetCallerIdentityCommand } from "@aws-sdk/client-sts";

const app = express();
app.use(cors());
app.use(express.json());

const REGION = "us-east-1";
const s3Client = new S3Client({ region: REGION });
const stsClient = new STSClient({ region: REGION });

const PREFIX = "users/";

async function getAccountId() {
  const data = await stsClient.send(new GetCallerIdentityCommand({}));
  return data.Account;
}

function streamToString(stream) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    stream.on("data", (chunk) => chunks.push(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
  });
}

// ------------------ Routes ------------------

app.get("/user", async (req, res) => {
  const accountId = await getAccountId();
  const BUCKET_NAME = `e-bank-user-data-${accountId}`;
  // const BUCKET_NAME = `e-bank-user-data-874924261412`;

  const username = req.query.username;
  if (!username) return res.status(400).json({ error: "Missing 'username'" });

  const key = `${PREFIX}${username}.json`;

  try {
    const getCmd = new GetObjectCommand({ Bucket: BUCKET_NAME, Key: key });
    const data = await s3Client.send(getCmd);
    const body = await streamToString(data.Body);
    res.status(200).json(JSON.parse(body));
  } catch (err) {
    console.error("GET error:", err);
    res
      .status(500)
      .json({ error: "Internal Server Error", details: err.message });
  }
});

app.post("/user", async (req, res) => {
  const accountId = await getAccountId();
  // const BUCKET_NAME = `e-bank-user-data-${accountId}`;
  const BUCKET_NAME = `e-bank-user-data-874924261412`;

  const body = req.body;
  const username = body.username;
  const key = `${PREFIX}${username}.json`;
  const { mode } = body;

  if (!username || !mode)
    return res.status(400).json({ error: "Missing username or mode" });

  try {
    if (mode === "signup") {
      const { id, email } = body;
      if (!id || !email)
        return res.status(400).json({ error: "Missing id or email" });

      await s3Client.send(
        new PutObjectCommand({
          Bucket: BUCKET_NAME,
          Key: key,
          Body: JSON.stringify(body, null, 2),
          ContentType: "application/json",
        })
      );
      return res.status(200).json({ message: "User signed up and saved", key });
    }

    if (mode === "login") {
      const getCmd = new GetObjectCommand({ Bucket: BUCKET_NAME, Key: key });
      const data = await s3Client.send(getCmd);
      const user = JSON.parse(await streamToString(data.Body));

      user.lastLogin = new Date().toISOString();

      await s3Client.send(
        new PutObjectCommand({
          Bucket: BUCKET_NAME,
          Key: key,
          Body: JSON.stringify(user, null, 2),
          ContentType: "application/json",
        })
      );
      return res.status(200).json({ message: "lastLogin updated", username });
    }

    if (mode === "transaction") {
      const { transaction } = body;

      if (
        !transaction ||
        !transaction.accountId ||
        !transaction.transactionId ||
        typeof transaction.amount !== "number" ||
        !transaction.type ||
        !transaction.date
      ) {
        return res
          .status(400)
          .json({ error: "Missing or invalid transaction data" });
      }

      const getCmd = new GetObjectCommand({ Bucket: BUCKET_NAME, Key: key });
      const data = await s3Client.send(getCmd);
      const user = JSON.parse(await streamToString(data.Body));

      const account = user.accounts.find(
        (acc) => acc.accountId === transaction.accountId
      );
      if (!account) return res.status(404).json({ error: "Account not found" });

      account.balance += ["receive", "deposit"].includes(transaction.type)
        ? transaction.amount
        : -transaction.amount;
      account.transactions.push(transaction);

      const month = new Date(transaction.date).toISOString().slice(0, 7);
      account.monthlyStats ||= {};
      account.monthlyStats[month] ||= { income: 0, spend: 0 };

      if (["receive", "deposit"].includes(transaction.type)) {
        account.monthlyStats[month].income += transaction.amount;
      } else {
        account.monthlyStats[month].spend += transaction.amount;
      }

      await s3Client.send(
        new PutObjectCommand({
          Bucket: BUCKET_NAME,
          Key: key,
          Body: JSON.stringify(user, null, 2),
          ContentType: "application/json",
        })
      );
      return res
        .status(200)
        .json({ message: "Transaction recorded", transaction });
    }

    return res.status(400).json({ error: "Invalid mode" });
  } catch (err) {
    console.error("POST error:", err);
    res
      .status(500)
      .json({ error: "Internal Server Error", details: err.message });
  }
});

// ------------------ Start Server ------------------

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Local backend running on http://localhost:${PORT}`);
});
