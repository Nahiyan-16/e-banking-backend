import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from "@aws-sdk/client-s3";
import { STSClient, GetCallerIdentityCommand } from "@aws-sdk/client-sts";

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

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
  };
}

function res(statusCode, body) {
  return {
    statusCode,
    headers: corsHeaders(),
    body: JSON.stringify(body),
  };
}

export const handler = async (event) => {
  if (event.httpMethod === "OPTIONS") {
    return { statusCode: 200, headers: corsHeaders(), body: "" };
  }

  const username =
    event.queryStringParameters?.username ||
    JSON.parse(event.body || "{}")?.username;
  if (!username) return res(400, { error: "Missing 'username'" });

  const accountId = await getAccountId();
  const BUCKET_NAME = `e-bank-user-data-${accountId}`;

  const key = `${PREFIX}${username}.json`;

  try {
    if (event.httpMethod === "GET") {
      const getCmd = new GetObjectCommand({ Bucket: BUCKET_NAME, Key: key });
      const data = await s3Client.send(getCmd);
      const body = await streamToString(data.Body);
      return res(200, JSON.parse(body));
    }

    if (event.httpMethod === "POST") {
      const requestBody =
        typeof event.body === "string" ? JSON.parse(event.body) : event.body;
      const { mode } = requestBody;

      if (!mode) return res(400, { error: "Missing 'mode'" });

      if (mode === "signup") {
        const { id, email } = requestBody;
        if (!id || !email)
          return res(400, {
            error: "Missing required fields for signup: id and email",
          });

        await s3Client.send(
          new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: key,
            Body: JSON.stringify(requestBody, null, 2),
            ContentType: "application/json",
          })
        );

        return res(200, { message: "User signed up and saved", key });
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

        return res(200, { message: "lastLogin updated", username });
      }

      if (mode === "transaction") {
        const { transaction } = requestBody;

        if (
          !transaction ||
          !transaction.accountId ||
          !transaction.transactionId ||
          typeof transaction.amount !== "number" ||
          !transaction.type ||
          !transaction.date
        ) {
          return res(400, { error: "Missing or invalid transaction data" });
        }

        const getCmd = new GetObjectCommand({ Bucket: BUCKET_NAME, Key: key });
        const data = await s3Client.send(getCmd);
        const user = JSON.parse(await streamToString(data.Body));

        const account = user.accounts.find(
          (acc) => acc.accountId === transaction.accountId
        );
        if (!account) return res(404, { error: "Account not found" });

        account.balance +=
          transaction.type === "receive" || transaction.type === "deposit"
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

        return res(200, { message: "Transaction recorded", transaction });
      }

      return res(400, { error: "Invalid mode" });
    }
  } catch (err) {
    console.error("Handler error:", err);
    return res(500, { error: "Internal Server Error", details: err.message });
  }
};
